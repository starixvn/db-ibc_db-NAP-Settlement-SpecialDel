/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Job]
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210208@Max: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets [Redmine: #150199]
		- 20210326@Max: [TVS] Enhance void queue and service integration [Redmine: #152053]
		- 20210401@Kathy:  Enhance Auto Void Retry process [Redmine:#152581]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RequestId			INT
			,@MatchId			INT
			,@VoidingHistoryId	INT
			,@VoidingTypeId		TINYINT
			,@QueueId			INT
			,@TransIds			VARCHAR(MAX)
			,@UserId			INT
			,@IP				VARCHAR(50)
			,@StatusId			TINYINT
			,@sessionID			INT = 0

			,@ErrCode			INT
			,@ErrMsg			VARCHAR(300)
			,@FailedTransIds	VARCHAR(MAX)
			,@NegativeBalanceUsers VARCHAR(MAX)
			,@IssueTypeId	TINYINT
			,@QueueIds VARCHAR(MAX)
			,@Status_Single TINYINT
			,@IsNoTicketFound BIT = 1
			,@IsExistError BIT = 0

			,@BypassCheckingProcess TINYINT = 0
			,@RetryTime INT = 120
			,@ExecTime DATETIME
			,@ErrMsgLockMatch VARCHAR(300) = '1000000'

	DECLARE @tmpQueue TABLE (
		RequestId		INT
		,QueueId		INT
		,MatchId		INT
		,VoidingTypeId	TINYINT
		,TransIds		VARCHAR(MAX)
		,UserId			INT
		,IP				VARCHAR(50)
		,IsFinished		BIT DEFAULT(0)
		,VoidingHistoryId	INT
	)

	DECLARE @tmpVoidBetAutomation_Service TABLE (
		RequestID	INT
	)

	DECLARE @tmpQueue_update TABLE (
		QueueId	INT
	)

	IF EXISTS(SELECT TOP 1 1 FROM dbo.TicketVoiding_Queue WHERE StatusId = 1)
		RETURN

	SELECT TOP (1) @VoidingHistoryId = q.VoidingHistoryId
			,@RequestId = q.RequestId
			,@ErrMsg = q.ErrMsg
	FROM	dbo.TicketVoiding_Queue q WITH(ROWLOCK)
		INNER JOIN dbo.TicketVoiding_VoidingHistory v WITH (NOLOCK) ON v.VoidingHistoryId = q.VoidingHistoryId AND v.StatusId = 1
	WHERE	q.StatusId = 0 -- waiting
			AND 1 = CASE 
						WHEN ErrMsg = @ErrMsgLockMatch AND DATEADD(SECOND, @RetryTime, DATEADD(MS, duration, Exectime)) > GETDATE() THEN 0
						ELSE 1
					END
	ORDER BY CASE WHEN ErrMsg = @ErrMsgLockMatch THEN DATEADD(SECOND, @RetryTime, DATEADD(MS, duration, Exectime)) ELSE Starttime END
			,q.VoidingHistoryId

	IF @@ROWCOUNT = 0
		RETURN
	
	INSERT INTO @tmpQueue (
		RequestId
		,QueueId
		,MatchId
		,VoidingTypeId
		,TransIds
		,UserId
		,IP
		,VoidingHistoryId
	)
	SELECT	RequestId
			,QueueId
			,MatchId
			,VoidingTypeId
			,TransIds
			,UserId
			,IP
			,@VoidingHistoryId
	FROM	dbo.TicketVoiding_Queue WITH(NOLOCK)
	WHERE	VoidingHistoryId = @VoidingHistoryId
			AND StatusId = 0
	
	SELECT	@IssueTypeId = IssueTypeId
	FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
	WHERE	EXISTS (SELECT TOP 1 1 FROM @tmpQueue t WHERE r.RequestId = t.RequestId)
	
	WHILE(1 = 1)
	BEGIN
		;WITH cteQueue
		AS(
			SELECT TOP 1 RequestId, QueueId, MatchId, VoidingTypeId, TransIds, UserId, IP, IsFinished
			FROM	@tmpQueue
			WHERE	IsFinished = 0
			ORDER BY CASE WHEN @IssueTypeId IN (1,10) THEN VoidingTypeId ELSE 1 END DESC
		)
		UPDATE	TOP (1) q 
			SET IsFinished = 1
				,@RequestId = q.RequestId
				,@QueueId = q.QueueId
				,@MatchId = q.MatchId
				,@VoidingTypeId = q.VoidingTypeId
				,@TransIds = q.TransIds
				,@UserId = q.UserId
				,@IP = q.IP
		FROM	cteQueue q
			INNER JOIN dbo.TicketVoiding_Queue t WITH (NOLOCK) ON t.QueueId = q.QueueId AND t.StatusId = 0

		IF @@ROWCOUNT = 0
			BREAK

		SELECT	@ErrCode = 0
				,@ErrMsg = ''
				,@FailedTransIds = ''
				,@StatusId = 1 -- running

		UPDATE	q  WITH(ROWLOCK, UPDLOCK)
			SET @ExecTime = GETDATE()
				,StatusId = @StatusId
				,Exectime = @ExecTime
				,ErrMsg = CASE WHEN  ErrMsg = @ErrMsgLockMatch THEN ErrMsg ELSE @ErrMsg END
		FROM	dbo.TicketVoiding_Queue q
		WHERE	q.QueueId = @QueueId

		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK) WHERE RequestID = @RequestId AND VoidingHistory = @VoidingHistoryId)
		BEGIN
			SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1

			INSERT INTO Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistory,statusID,matchID,SessionID, IsAutoVoid)
			SELECT @RequestId, @VoidingHistoryId,1,CASE WHEN @IssueTypeId <> 13 THEN @MatchId ELSE NULL END,@sessionID,0
		END

		IF @IssueTypeId IN (1,10) AND @BypassCheckingProcess = 0 -- if issuetype is danger accept or redcard, lock match for single ticket and lock parlay 
		BEGIN
			EXEC dbo.TicketVoiding_Request_CheckingProcess
				@VoidingHistoryId = @VoidingHistoryId
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT

			IF @ErrCode = 0
				SET @BypassCheckingProcess = 1
			ELSE
			BEGIN
				UPDATE	q WITH(ROWLOCK, UPDLOCK)
					SET @StatusId = CASE WHEN ErrMsg = CAST(@ErrCode AS VARCHAR) THEN 3 ELSE 0 END
						,ErrMsg = CASE WHEN @StatusId = 3 THEN @ErrMsg ELSE CAST(@ErrCode AS VARCHAR) END
						,StatusId = @StatusId
						,FailedTransIds = CASE WHEN @StatusId = 3 THEN TransIds ELSE NULL END
						,Duration = DATEDIFF(MS, @Exectime, GETDATE())
						,Exectime = @ExecTime
				FROM	dbo.TicketVoiding_Queue q
				WHERE	RequestId = @RequestId
						AND VoidingHistoryId = @VoidingHistoryId
		
				IF @StatusId = 3 -- after retry
				BEGIN
					UPDATE s WITH (ROWLOCK, UPDLOCK)
						SET statusID = 3 -- Failed
					FROM	dbo.Ticketvoiding_VoidBetAutomation_Service s 
					WHERE	RequestID = @RequestId 
							AND VoidingHistory = @VoidingHistoryId
				END
				RETURN
			END
		END
		
		IF @BypassCheckingProcess > 0
		BEGIN
			IF @VoidingTypeId = 2 AND EXISTS (SELECT TOP 1 1 FROM @tmpQueue WHERE IsFinished = 0 AND VoidingTypeId = @VoidingTypeId AND QueueId <> @QueueId) -- parlay
				SET @BypassCheckingProcess = 3 -- keep locking until the last row of parlay executed
			ELSE
				SET @BypassCheckingProcess = 1
		END

		BEGIN TRY
			EXEC dbo.TicketVoiding_Ticket_Update
				@RequestId = @RequestId
				,@MatchId = @MatchId
				,@TransIds = @TransIds
				,@VoidingHistoryId = @VoidingHistoryId
				,@VoidingTypeId = @VoidingTypeId
				,@UserId = @UserId
				,@IP = @IP
				,@BypassCheckingProcess = @BypassCheckingProcess
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
				,@FailedTransIds = @FailedTransIds OUTPUT
				,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
				,@QueueIds = @QueueIds OUTPUT

		END TRY
		BEGIN CATCH
			SELECT	@StatusId = 3 -- failed
					,@ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
					,@FailedTransIds = @FailedTransIds
					,@NegativeBalanceUsers = @NegativeBalanceUsers

					,@IsExistError = 1
					,@IsNoTicketFound = 0
		END CATCH

		SET @StatusId = CASE WHEN @ErrCode <> 0 AND @ErrCode <> 100 THEN 3 ELSE 2 END

		IF @IssueTypeId = 13
		BEGIN
			INSERT INTO @tmpQueue_update(QueueId)
			SELECT	val AS TransId
			FROM	dbo.f_SplitString(@QueueIds, ',')
			OPTION (maxrecursion 0)
		END
		ELSE 
		BEGIN
			INSERT INTO @tmpQueue_update(QueueId)
			SELECT	@QueueId
			FROM	@tmpQueue
			WHERE	QueueId = CASE 
								WHEN @IssueTypeId IN (1,10) AND @StatusId = 3 THEN QueueId
								ELSE @QueueId
							END
		END

		UPDATE	q WITH(ROWLOCK, UPDLOCK)
			SET	Duration = CASE WHEN q.QueueId = @QueueId THEN DATEDIFF(MILLISECOND, q.Exectime, GETDATE())	ELSE Duration END
				,StatusId = @StatusId
				,ErrMsg = CASE WHEN q.QueueId = @QueueId THEN @ErrMsg ELSE ErrMsg END
				,FailedTransIds = @FailedTransIds
				,NegativeBalanceUsers = CASE WHEN q.QueueId = @QueueId THEN @NegativeBalanceUsers ELSE NegativeBalanceUsers END
		FROM	dbo.TicketVoiding_Queue q
		WHERE 1 = CASE WHEN @IssueTypeId = 13 AND EXISTS (SELECT QueueId FROM @tmpQueue_update WHERE QueueId = q.QueueId) THEN 1
						WHEN @IssueTypeId <> 13 AND q.QueueId = @QueueId THEN 1
					ELSE 0 END

		IF @StatusId = 3
			SET @IsExistError = 1

		IF @ErrCode <> 100
			SET @IsNoTicketFound = 0
	END

	UPDATE s WITH (ROWLOCK, UPDLOCK)
		SET s.statusID = CASE WHEN @IsNoTicketFound = 1 THEN 12 -- Service completed
								WHEN @IsExistError = 1 THEN 3 -- Failed
								ELSE 2 END -- DB completed
			,s.NegativeBalanceUsers = @NegativeBalanceUsers
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service s 
	WHERE RequestID = @RequestId AND VoidingHistory = @VoidingHistoryId

	IF @IsNoTicketFound = 1 --'No ticket found.'
	BEGIN
		UPDATE vh WITH (ROWLOCK, UPDLOCK)
			SET vh.statusID = 2 -- Completed
		FROM dbo.TicketVoiding_VoidingHistory vh
		WHERE RequestID = @RequestId AND VoidingHistoryId = @VoidingHistoryId
	END

END

GO


