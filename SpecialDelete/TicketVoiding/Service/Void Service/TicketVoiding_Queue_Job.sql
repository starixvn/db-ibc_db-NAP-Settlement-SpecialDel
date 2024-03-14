/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet,wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Queue_Job]
(
	@QueueId INT
	,@IsCalledNetPosition BIT = 1
)
AS
/*	
	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210208@Max: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets [Redmine: #150199]
		- 20210326@Max: [TVS] Enhance void queue and service integration [Redmine: #152053]
		- 20210401@Kathy:  Enhance Auto Void Retry process [Redmine:#152581]
		- 20210511@Max: TVS - Wrong Score [Redmine: #140953]
		- 20210622@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20211223@Max: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220404@Max: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221201@Max: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230517@Max: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20231227@Max: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @RequestId			INT
			,@MatchId			INT
			,@VoidingHistoryId	INT
			,@VoidingTypeId		TINYINT
			,@TransIds			VARCHAR(MAX)
			,@UserId			INT
			,@IP				VARCHAR(50)
			,@StatusId			TINYINT
			,@ErrCode			INT
			,@ErrMsg			VARCHAR(300)
			,@FailedTransIds	VARCHAR(MAX)
			,@NegativeBalanceUsers VARCHAR(MAX)
			,@IssueTypeId	TINYINT
			,@BypassCheckingProcess TINYINT = 0
			,@ExecTime DATETIME
			,@ErrMsgLockMatch VARCHAR(300) = '1000000'
			,@StatusMove TINYINT
			,@ErrMsgMove VARCHAR(300)
			,@MoveBetMatchIds VARCHAR(MAX) = NULL
			,@MoveBetMatchIdsXML XML = NULL
			,@ResettledTransIds	VARCHAR(MAX) = NULL


	DECLARE @tmpMatchMoveBet_update TABLE (
		MatchId	INT
	   ,TransIds VARCHAR(MAX)
	)

	SELECT	@RequestId = q.RequestId
			,@MatchId =q.MatchId
			,@VoidingTypeId = q.VoidingTypeId
			,@TransIds = q.TransIds
			,@UserId = q.UserId
			,@IP = q.IP
			,@VoidingHistoryId = q.VoidingHistoryId
			,@IssueTypeId = q.IssueTypeId
	FROM	dbo.TicketVoiding_Queue q WITH(NOLOCK)
	WHERE	QueueId = @QueueId

	SELECT	@ErrCode = 0
			,@ErrMsg = ''
			,@FailedTransIds = ''

	UPDATE	q  WITH(ROWLOCK, UPDLOCK)
		SET @ExecTime = GETDATE()
			,Exectime = @ExecTime
	FROM	dbo.TicketVoiding_Queue q
	WHERE	q.QueueId = @QueueId

	IF @VoidingTypeId = 4 AND @IsCalledNetPosition = 0
	BEGIN
		UPDATE	q WITH(ROWLOCK, UPDLOCK)
		SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())
			,StatusId = 3
			,ErrMsg = 'Failed to adjust Net Position of credit Members, consequently their ''Match Winner'' tickets have not been voided.'
			,FailedTransIds =  q.TransIds
		FROM	dbo.TicketVoiding_Queue q
		WHERE q.QueueId = @QueueId 
	END
	ELSE
	BEGIN
		BEGIN TRY
			EXEC dbo.TicketVoiding_Ticket_Update
				@RequestId = @RequestId
				,@MatchId = @MatchId
				,@TransIds = @TransIds
				,@VoidingHistoryId = @VoidingHistoryId
				,@VoidingTypeId = @VoidingTypeId
				,@UserId = @UserId
				,@IP = @IP
				,@IssueTypeId = @IssueTypeId
				,@ErrCode = @ErrCode OUTPUT
				,@ErrMsg = @ErrMsg OUTPUT
				,@FailedTransIds = @FailedTransIds OUTPUT
				,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
				,@MoveBetMatchIds = @MoveBetMatchIds OUTPUT
				,@ResettledTransIds = @ResettledTransIds OUTPUT

		END TRY
		BEGIN CATCH
			SELECT	@StatusId = 3 -- failed
					,@ErrCode = ERROR_NUMBER()
					,@ErrMsg = SUBSTRING(ERROR_PROCEDURE() + ': ' + ERROR_MESSAGE(), 1, 300)
					,@FailedTransIds = @FailedTransIds
					,@NegativeBalanceUsers = @NegativeBalanceUsers
		END CATCH

		IF @ErrCode = @ErrMsgLockMatch
		BEGIN 
			UPDATE	q WITH(ROWLOCK, UPDLOCK)
				SET @StatusId = CASE WHEN ErrMsg = CAST(@ErrCode AS VARCHAR) THEN 3 ELSE 1 END
					,ErrMsg = CASE WHEN @StatusId = 3 THEN @ErrMsg ELSE CAST(@ErrCode AS VARCHAR) END
					,StatusId = @StatusId
					,FailedTransIds = CASE WHEN @StatusId = 3 THEN TransIds ELSE NULL END
					,Duration = DATEDIFF(MS, @Exectime, GETDATE())
					,Exectime = @ExecTime
			FROM	dbo.TicketVoiding_Queue q
			WHERE	QueueId = @QueueId

			SELECT q.QueueId, q.StatusId, q.ErrMsg AS [Message], q.UserId, c.username
			FROM dbo.TicketVoiding_Queue q WITH (NOLOCK)
				INNER JOIN CustDB.dbo.CustInfo c WITH (NOLOCK) ON c.custid = q.UserId
			WHERE q.QueueId = @QueueId
		
			RETURN
		END

		SET @StatusId = CASE WHEN @ErrCode <> 0 AND @ErrCode <> 100 THEN 3 ELSE 2 END

		IF @MoveBetMatchIds IS NOT NULL
		BEGIN
			SELECT @StatusMove = 3, @ErrMsgMove = 'Could not void some tickets due to Movebet process.'

			SET @MoveBetMatchIdsXML = CONVERT(XML, @MoveBetMatchIds)

			INSERT INTO @tmpMatchMoveBet_update(MatchId, TransIds)
			SELECT   T.C.value('@MatchId', 'INT') AS MatchId
					,T.C.value('@TransIds', 'VARCHAR(MAX)') AS TransIds
			FROM @MoveBetMatchIdsXML.nodes('/root/r') as [T](C)
		END
	
		UPDATE	q WITH(ROWLOCK, UPDLOCK)
		SET	Duration = DATEDIFF(MILLISECOND, q.Exectime, GETDATE())
			,StatusId = CASE WHEN m.MatchId IS NULL THEN @StatusId ELSE @StatusMove END
			,ErrMsg = CASE WHEN m.MatchId IS NULL THEN @ErrMsg 
							WHEN m.MatchId IS NOT NULL THEN @ErrMsgMove 						
							ELSE ErrMsg END
			,FailedTransIds = CASE WHEN m.MatchId NOT IN (9,29,2799,10449) THEN q.TransIds
									WHEN m.MatchId IN (9,29,2799,10449) THEN m.TransIds
									ELSE @FailedTransIds END
			,NegativeBalanceUsers = @NegativeBalanceUsers
		FROM	dbo.TicketVoiding_Queue q
			LEFT JOIN @tmpMatchMoveBet_update m ON q.MatchId = m.MatchId
		WHERE q.QueueId = @QueueId 
	END
	
	SELECT q.QueueId, q.StatusId, q.VoidingHistoryId
		, q.RequestId, q.MatchId, q.VoidingTypeId, q.NegativeBalanceUsers
		, q.ErrMsg, q.UserId, c.username, @ResettledTransIds AS ResettledTransIds
	FROM dbo.TicketVoiding_Queue q WITH (NOLOCK)
		INNER JOIN CustDB.dbo.CustInfo c WITH (NOLOCK) ON c.custid = q.UserId
	WHERE q.QueueId = @QueueId

END

GO


