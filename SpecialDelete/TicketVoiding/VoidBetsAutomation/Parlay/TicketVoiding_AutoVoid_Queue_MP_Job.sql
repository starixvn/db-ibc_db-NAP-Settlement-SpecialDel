/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoid_Queue_MP_Job]
AS
/*	
	Created by: Max
	Date 20211116
	Task: [TVS] Void abnormal bet of parlay
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20211116@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]

	Param's explanation:	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @RequestId			INT
			,@MatchId			INT
			,@QueueId			INT
			,@UserId			INT = 10278938
			,@Action			VARCHAR(50)
			,@IP				VARCHAR(50) = '125.227.140.97'
			,@StatusId			TINYINT = 1
			,@ErrCode			INT
			,@ErrMsg			VARCHAR(300)
			,@NegativeBalanceUsers VARCHAR(MAX)
			,@Max_QueueId		INT = 0
			,@Min_QueueId		INT = 0
			,@VoidingHistoryIds VARCHAR(MAX) = ''
			,@MoveBetMatchIds	VARCHAR(MAX)

	DECLARE @VoidingHistory_tmp AS TABLE (VoidingHistoryId INT)
	DECLARE @tmpMatchMoveBet_update TABLE (MatchId	INT)	
	DECLARE @tmpMatch TABLE (MatchId INT)
	
	IF EXISTS(SELECT TOP 1 1 FROM dbo.TicketVoiding_AutoVoidRequest_Queue WHERE StatusId = 1)
		RETURN

	----- Starting auto voiding process--------
	CREATE TABLE #Match_AutoVoid (QueueId INT, matchid INT, RequestId INT)
	CREATE TABLE #tblRequestList (RequestID INT PRIMARY KEY, IsFinished INT DEFAULT(0))

	SELECT @Max_QueueId = MAX(q.QueueId)
		  ,@Min_QueueId = MIN(q.QueueId)
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH (NOLOCK)
	WHERE q.StatusId = 0

	--Update cancel for action change to Manual Action
	UPDATE q
		SET StatusId = 4
			,ErrMsg = 'Change action from AutoVoid to other action'
			,Exectime = GETDATE()
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK)
		CROSS APPLY (
				SELECT TOP 1 ActionId
				FROM dbo.TicketVoiding_Request r WITH (NOLOCK)	
					INNER JOIN dbo.TicketVoiding_RequestDetail rd with (nolock) on rd.RequestId = r.RequestId and rd.FilterBy = 1
				WHERE r.RequestId = q.RequestId
			)r
	WHERE q.StatusId = 0 
		AND r.ActionId NOT IN (1,4,8)
		AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
	
	INSERT #Match_AutoVoid (QueueId, matchid, RequestId)
	SELECT q.QueueId, q.matchid, q.RequestId
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = q.RequestId
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = r.RequestId
	WHERE q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
		AND q.StatusId = 0
		AND rd.FilterBy = 1
		AND r.IssueTypeId = 11
		AND 1 = CASE WHEN r.ActionId = 1 AND DATEADD(SECOND,60,q.Starttime) <= GETDATE() THEN 1
					WHEN r.ActionId IN (4,8) THEN 1
				ELSE 0 END
	UNION ALL
	SELECT q.QueueId, q.matchid, q.RequestId
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH(NOLOCK)
	WHERE q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
		AND q.StatusId = 100
		AND DATEADD(SECOND,600,q.Starttime) <= GETDATE() 
	
	INSERT INTO #tblRequestList (RequestID)
	SELECT DISTINCT RequestId
	FROM #Match_AutoVoid
		
	WHILE(1=1)
	BEGIN
		DELETE @tmpMatch

		UPDATE TOP (1) t
		SET t.IsFinished = 1
			, @RequestId = t.RequestId
		FROM #tblRequestList t
		WHERE IsFinished = 0 
		
		IF @@ROWCOUNT = 0 
			BREAK
		
		UPDATE	q  WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 1
				,Exectime = GETDATE()
		FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q
				INNER JOIN #Match_AutoVoid m ON m.QueueId = q.QueueId
		WHERE	q.RequestId = @RequestId

		INSERT INTO @tmpMatch (MatchId)
		SELECT m.matchid
		FROM #Match_AutoVoid m
		WHERE m.RequestId = @RequestId

		BEGIN TRY
			EXEC dbo.TicketVoiding_AutoVoid_Update_MP 
				@MatchId = 29
				,@UserId = @UserId
				,@RequestId = @RequestId
				,@IP = @IP
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
				,@VoidingHistoryIds = @VoidingHistoryIds OUTPUT
				,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
				,@MoveBetMatchIds = @MoveBetMatchIds OUTPUT
			
			SET @StatusId = CASE WHEN @ErrCode <> 0 THEN 3 ELSE 2 END
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
		END CATCH
		
		INSERT INTO @VoidingHistory_tmp(VoidingHistoryId)
		SELECT	val AS TransId
		FROM	dbo.f_SplitString(@VoidingHistoryIds, ',')
		OPTION (maxrecursion 0)

		IF (ISNULL(@ErrCode, 0) <> 0 )
		BEGIN
			IF @ErrCode = 9999 -- error due to lock match
			BEGIN
				UPDATE q SET StatusId = 0
				FROM dbo.TicketVoiding_AutoVoidRequest_Queue q WITH (ROWLOCK, UPDLOCK)
					INNER JOIN #Match_AutoVoid m ON m.QueueId = q.QueueId
				WHERE q.RequestId = @RequestId
			
			END
			ELSE -- other errors
			BEGIN
				UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
					,StatusId = 3
					,ErrMsg = @ErrMsg
				FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q
					INNER JOIN #Match_AutoVoid m ON m.QueueId = q.QueueId
				WHERE q.RequestId = @RequestId	

				UPDATE s WITH (ROWLOCK, UPDLOCK)
					SET s.statusID = 3
				FROM dbo.Ticketvoiding_VoidBetAutomation_Service s 
					INNER JOIN @VoidingHistory_tmp v ON v.VoidingHistoryId = s.VoidingHistory
			END
		END
		ELSE
		BEGIN
			--Update statusid = 0 to run in next turn
			IF EXISTS (SELECT TOP (1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
										INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.TransId
									WHERE s.RequestId = @RequestId AND b.statusID IN (0,1) AND b.statuswinlost IS NOT NULL)
			BEGIN
				UPDATE	q WITH(ROWLOCK, UPDLOCK)
					SET	StatusId = 0
						,Starttime = GETDATE()
				FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q 
				WHERE q.RequestId = @RequestId
					AND q.StatusId IN (0,1,99)
			END
			ELSE IF EXISTS (SELECT TOP (1) 1 FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
										INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = s.TransId
									WHERE s.RequestId = @RequestId AND b.statusID IN (0,1) AND b.statuswinlost IS NULL)
			BEGIN
				IF EXISTS (SELECT TOP (1) 1 FROM @tmpMatch tm
										INNER JOIN dbo.match m WITH (NOLOCK) ON tm.MatchId = m.matchid
									WHERE m.eventstatus <> 'completed')
				BEGIN
					UPDATE	q WITH(ROWLOCK, UPDLOCK)
						SET	Duration = CASE WHEN q.StatusId = 1 THEN DATEDIFF(MILLISECOND, q.Exectime, GETDATE()) ELSE 0 END			
							,StatusId = 99
							,ErrMsg = @ErrMsg
					FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q 
					WHERE q.RequestId = @RequestId
						AND q.StatusId IN (0,1,99)
				END
				ELSE
				BEGIN
					UPDATE	q WITH(ROWLOCK, UPDLOCK)
						SET	Duration = CASE WHEN q.StatusId = 1 THEN DATEDIFF(MILLISECOND, q.Exectime, GETDATE()) ELSE 0 END			
							,StatusId = 99
							,ErrMsg = @ErrMsg
							,Starttime = GETDATE()
					FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q 
					WHERE q.RequestId = @RequestId
						AND q.StatusId IN (0,1,99)
				END
			END
			ELSE
			BEGIN
				UPDATE	q WITH(ROWLOCK, UPDLOCK)
					SET	Duration = CASE WHEN q.StatusId = 1 THEN DATEDIFF(MILLISECOND, q.Exectime, GETDATE()) ELSE 0 END			
						,StatusId = 2
						,ErrMsg = @ErrMsg
				FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q 
				WHERE q.RequestId = @RequestId
					AND q.StatusId IN (0,1,99)
			END
			
			UPDATE s WITH (ROWLOCK, UPDLOCK)
				SET s.statusID = 2
					,s.NegativeBalanceUsers = @NegativeBalanceUsers
			FROM dbo.Ticketvoiding_VoidBetAutomation_Service s 
				INNER JOIN @VoidingHistory_tmp v ON v.VoidingHistoryId = s.VoidingHistory
		END
		
		IF @MoveBetMatchIds IS NOT NULL
		BEGIN
			SELECT	@StatusId= 3, @ErrMsg = 'Could not void some tickets due to Movebet process.'

			INSERT INTO @tmpMatchMoveBet_update(MatchId)
			SELECT	val AS MatchId
			FROM	dbo.f_SplitString(@MoveBetMatchIds, ',')
			OPTION (maxrecursion 0)

			UPDATE	q WITH(ROWLOCK, UPDLOCK)
			SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
				,StatusId = @StatusId
				,ErrMsg = @ErrMsg
			FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q
				INNER JOIN @tmpMatchMoveBet_update m ON q.MatchId = m.MatchId
			WHERE q.RequestId  = @RequestId

			UPDATE s WITH (ROWLOCK, UPDLOCK)
			SET s.statusID = 3
			FROM dbo.Ticketvoiding_VoidBetAutomation_Service s 
				INNER JOIN @VoidingHistory_tmp v ON v.VoidingHistoryId = s.VoidingHistory
		END	
			
	END

	DROP TABLE #Match_AutoVoid
	DROP TABLE #tblRequestList
END		
GO


