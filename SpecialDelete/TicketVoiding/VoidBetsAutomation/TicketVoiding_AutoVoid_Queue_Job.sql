/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoid_Queue_Job]
AS
/*	Created by: Helen
	Date 20200212
	Task: [TVS] Abnormal Void Bets Automation
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Helen:[TVS] Abnormal Void Bets Automation [Redmine:#127398]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200316@Max: HotFix - Update item to Cancel even there are requests need to be executed [Redmine: #130303]
		- 20200325@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis + hotfix [Redmine:#131516]
		- 20200513@Helen: TVS insert into Queue multi when edit request [Redmine:#134107]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		
	Param's explanation:	
	
	--[Action] IN ('CAL-HT','CAL-FT','CAL','CAL-EARLY')
	select * from (
	select 'CAL-HT' as action
	union all select 'CAL-FT'
	union all select 'CAL'
	union all select 'CAL-EARLY') AS t
	order by action 
	
	Notes for early:
	+ Soccer: 
		@Action: CAL, UNDO, REFUND,@Action + '-' + 'EARLY'
		-> queue: ,@Action + '-' + 'EARLY'
	+ Badminton and Esport:
		@Action:CAL_EAR, UNDO_EAR, REFUND_EAR
		-> queue: 'CAL'	
	+ Basketball:
		@Action: CAL, UNDO, REFUND
		-> queue: 'CAL-EARLY'
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @RequestId			INT
			,@MatchId			INT
			,@QueueId			INT
			,@UserId			INT = 10278938
			,@Action			VARCHAR(50)
			,@Checktime			DATETIME
			,@IP				VARCHAR(50) = '125.227.140.97'
			,@StatusId			TINYINT = 1
			,@RequestIDList		VARCHAR(MAX) = NULL
			,@ErrCode			INT
			,@ErrMsg			VARCHAR(300)
			,@NegativeBalanceUsers VARCHAR(MAX)
			,@MatchidList_Waiting_10minutes VARCHAR(MAX) = ''
			,@TransIDList_tmp	VARCHAR(MAX)= ''
			,@Sporttype			SMALLINT 
			,@queue_cnt			INT 
			,@Max_QueueId		INT = 0

			
	--SEND NOTIFICATION VIA EMAIL FOR LOCAL
	DECLARE @Subject	NVARCHAR(500) = ''
		,@Body			NVARCHAR(MAX) = ''
		,@Recipients	VARCHAR(MAX) = ''	
	-- SEND NOTIFICATION VIA LESTALK ON PRODUCTION
	DECLARE @msg NVARCHAR(4000)	= ''
		,@title NVARCHAR(200)	= 'AutoVoid: Notification'
	
	DECLARE @tblRequestList AS TABLE (QueueID INT, Matchid INT, RequestID INT)
	
	DECLARE @tblMatchid_abnormal AS TABLE (matchid INT)
	
	-------------------STARTING OF Process invalid request -----------
	-- update cancel: check abnormalbet and any mark ticket by auto
	SET @Max_QueueId = (SELECT MAX(q.QueueId) FROM TicketVoiding_AutoVoidRequest_Queue q WITH (NOLOCK))

	INSERT INTO @tblMatchid_abnormal (matchid)
	SELECT DISTINCT rd.matchid
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			INNER JOIN TicketVoiding_AutoVoidRequest_Queue q (NOLOCK) ON q.MatchId = rd.MatchId
	WHERE req.IssueTypeId = 11 AND q.StatusId = 0 AND q.RequestId = 0 AND q.QueueId <= @Max_QueueId
	
	
	UPDATE q
		SET StatusId = 4
			,ErrMsg = 'None of AbnormalBet Request AND None of mark ticket by Auto Service.'
			,Exectime = GETDATE()
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK)
		LEFT JOIN @tblMatchid_abnormal m ON q.MatchId = m.matchid
		OUTER APPLY (SELECT TOP 1 transid
					FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
					WHERE mt.MatchId = q.matchid AND mt.MarkType = 2
					) AS mt_tmp 
	WHERE q.StatusId = 0 
		AND q.RequestId = 0 
		AND mt_tmp.TransId IS NULL AND m.matchid IS NULL	
		AND q.QueueId <= @Max_QueueId
	
	-------------------END OF Process invalid request-----------	
	IF EXISTS(SELECT TOP 1 1 FROM dbo.TicketVoiding_AutoVoidRequest_Queue WHERE StatusId = 1)
		RETURN


	----- Starting auto voiding process: FIFO --------
	CREATE TABLE #Match_AutoVoid (QueueId INT, matchid INT, IsFinished INT DEFAULT(0))

	INSERT #Match_AutoVoid (QueueId, matchid)
	SELECT q.QueueId, q.matchid
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK)
		LEFT JOIN dbo.TempVariableNumber t WITH (NOLOCK) ON q.MatchId = t.KeyValue
	WHERE StatusId = 0 AND t.KeyID IS NULL -- waiting
	ORDER BY q.Action DESC, Starttime
	
	WHILE(1=1)
	BEGIN
		SELECT TOP (1) @queue_cnt = QueueId, @MatchId = matchid FROM #Match_AutoVoid WHERE IsFinished = 0
		IF @@ROWCOUNT = 0 
			BREAK

		SELECT TOP (1) @QueueId = QueueId, @RequestId = RequestId
						, @Action = Action 
						, @MatchId = matchID
						, @Checktime = DATEADD(SECOND,300,Starttime)
						,@Sporttype = sporttype
		FROM	dbo.TicketVoiding_AutoVoidRequest_Queue WITH(ROWLOCK)
		WHERE	MatchId = @MatchId AND StatusId = 0 -- waiting
		ORDER BY RequestId, Action, Starttime DESC
	
		IF @RequestId = 0 AND @Checktime > GETDATE()
			CONTINUE
		
		IF @RequestId > 0
		BEGIN
			SET @RequestIDList = CAST(@RequestId AS VARCHAR(50))
		END

		UPDATE	q  WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 1
				,Exectime = GETDATE()
		FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q
		WHERE	q.QueueId = @QueueId

		BEGIN TRY
			EXEC dbo.TicketVoiding_AutoVoid_Update 
				@MatchId = @MatchId
				,@Sporttype = @Sporttype
				,@UserId = @UserId
				,@Action = @Action
				,@RequestIdList = @RequestIdList
				,@IP = @IP
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
			
			SET @StatusId = CASE WHEN @ErrCode <> 0 THEN 3 ELSE 2 END
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
		END CATCH
	
		IF (ISNULL(@ErrCode, 0) <> 0 )
		BEGIN
			IF @ErrCode = 9999 -- error due to lock match
			BEGIN
				UPDATE dbo.TicketVoiding_AutoVoidRequest_Queue WITH (ROWLOCK, UPDLOCK)
				SET StatusId = 0
				WHERE QueueId = @QueueId
			
			END
			ELSE -- other errors
			BEGIN
				UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
					,StatusId = 3
					,ErrMsg = @ErrMsg
				FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q
				WHERE	QueueId = @QueueId 					
			END
			RETURN
		END
	
		IF @RequestId > 0
		BEGIN
			UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
					,StatusId = 2
					,ErrMsg = @ErrMsg
			FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q 
			WHERE q.QueueId = @QueueId
			
		END
		ELSE
		BEGIN
			UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = CASE WHEN QueueId = @QueueId THEN DATEDIFF(MILLISECOND, q.Exectime, GETDATE()) ELSE Duration END 				
					,StatusId = CASE WHEN QueueId = @QueueId THEN 2 ELSE 4 END -- StatusID = 4: Cancelled
					,ErrMsg = CASE WHEN QueueId = @QueueId THEN @ErrMsg ELSE ErrMsg END 
			FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q
			WHERE	QueueId <= @QueueId 
					AND q.MatchId = @MatchId 
					AND q.StatusId IN (0,1)
					AND 1 = CASE 
								WHEN QueueId = @QueueId THEN 1	
								-- Soccer & basketball : Cal manually
								WHEN @Sporttype IN (1,2) AND @Action = 'CAL' AND q.Action IN ('CAL-HT','CAL-FT') THEN 1
								ELSE 0
							END	  
		END

		IF @RequestId > 0
		BEGIN
			UPDATE #Match_AutoVoid SET IsFinished = 1 WHERE QueueId = @queue_cnt AND matchid = @MatchId AND IsFinished = 0
		END
		ELSE
		BEGIN
			UPDATE #Match_AutoVoid SET IsFinished = 1 WHERE matchid = @MatchId AND IsFinished = 0
		END
	END

END		
GO


