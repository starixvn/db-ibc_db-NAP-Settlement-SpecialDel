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
		- 20201211@July: [TVS] - Enhance TVS Queue data storage - [Redmine: #146805]
		- 20201220@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		
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
			,@Max_QueueId		INT = 0
			,@Min_QueueId		INT = 0
			,@VoidingHistoryIds VARCHAR(MAX) = ''
	
	DECLARE @VoidingHistory_tmp AS TABLE (VoidingHistoryId INT)

			
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
	SELECT @Max_QueueId = MAX(q.QueueId)
		  ,@Min_QueueId = MIN(q.QueueId)
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH (NOLOCK)
	WHERE q.StatusId = 0

	INSERT INTO @tblMatchid_abnormal (matchid)
	SELECT DISTINCT rd.matchid
	FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			INNER JOIN TicketVoiding_AutoVoidRequest_Queue q (NOLOCK) ON q.MatchId = rd.MatchId 
	WHERE req.IssueTypeId = 11 AND q.StatusId = 0 
			AND q.RequestId = 0 AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
		
	UPDATE q
		SET StatusId = 4
			,ErrMsg = 'None of AbnormalBet Request AND None of marked ticket'
			,Exectime = GETDATE()
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH(ROWLOCK)
		LEFT JOIN @tblMatchid_abnormal m ON q.MatchId = m.matchid
		OUTER APPLY (SELECT TOP 1 transid
					FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
					WHERE mt.MatchId = q.matchid
					) AS mt_tmp 
	WHERE q.StatusId = 0 
		AND q.RequestId = 0 
		AND mt_tmp.TransId IS NULL AND m.matchid IS NULL	
		AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId
	
	-------------------END OF Process invalid request-----------	
	IF EXISTS(SELECT TOP 1 1 FROM dbo.TicketVoiding_AutoVoidRequest_Queue WHERE StatusId = 1)
		RETURN

	----- Starting auto voiding process--------
	CREATE TABLE #Match_AutoVoid (QueueId INT, matchid INT, RequestId INT, Sporttype INT, IsFinished INT DEFAULT(0))

	INSERT #Match_AutoVoid (QueueId, matchid, RequestId, Sporttype)
	SELECT q.QueueId, q.matchid, q.RequestId, q.sporttype
	FROM TicketVoiding_AutoVoidRequest_Queue q WITH(NOLOCK)
		LEFT JOIN dbo.TempVariableNumber t WITH (NOLOCK) ON q.MatchId = t.KeyValue AND t.KeyID = 1
	WHERE StatusId = 0 AND t.KeyID IS NULL -- waiting
		AND 1 = CASE WHEN q.RequestId = 0 AND DATEADD(SECOND,300,Starttime) <= GETDATE() THEN 1 
					WHEN q.RequestId > 0 THEN 1
				ELSE 0 END
		AND q.QueueId BETWEEN @Min_QueueId AND @Max_QueueId	
	ORDER BY q.Action DESC, Starttime
	
	WHILE(1=1)
	BEGIN
		UPDATE TOP (1) t
		SET t.IsFinished = 1
			, @QueueId = t.QueueId
			, @RequestId = t.RequestId
			, @MatchId = t.matchid
			, @Sporttype = t.Sporttype
		FROM #Match_AutoVoid t
		WHERE IsFinished = 0 
		
		IF @@ROWCOUNT = 0 
			BREAK
		
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
				,@RequestId = @RequestId
				,@IP = @IP
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
				,@VoidingHistoryIds = @VoidingHistoryIds OUTPUT
				,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			
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

				UPDATE s WITH (ROWLOCK, UPDLOCK)
					SET s.statusID = 3
				FROM dbo.Ticketvoiding_VoidBetAutomation_Service s 
					INNER JOIN @VoidingHistory_tmp v ON v.VoidingHistoryId = s.VoidingHistory
			END
		END
		ELSE
		BEGIN
			UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())				
					,StatusId = 2
					,ErrMsg = @ErrMsg
			FROM	dbo.TicketVoiding_AutoVoidRequest_Queue q 
			WHERE q.QueueId = @QueueId
			
			UPDATE s WITH (ROWLOCK, UPDLOCK)
				SET s.statusID = 2
					,s.NegativeBalanceUsers = @NegativeBalanceUsers
			FROM dbo.Ticketvoiding_VoidBetAutomation_Service s 
				INNER JOIN @VoidingHistory_tmp v ON v.VoidingHistoryId = s.VoidingHistory
		END
			
	END

	DROP TABLE #Match_AutoVoid
END		
GO


