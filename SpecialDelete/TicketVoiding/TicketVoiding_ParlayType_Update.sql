/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ParlayType_Update]
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)

	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
AS
/*	Created by: Kathy
	Date 20181212
	Task: view voided ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200825@Max: [TVS] HotFix - Danger Accept [Redmine: #140164]
		
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

	DECLARE @avaiableProcess BIT
			,@MatchDate DATETIME
			,@RowId INT
			,@RowCount INT
			,@strSubTransId VARCHAR(MAX)
			,@strMainTransId VARCHAR(MAX)
			,@strRefno VARCHAR(MAX)
			,@CustIds VARCHAR(MAX)

	DECLARE @tblDebitPending TVP_BalanceList  
	DECLARE @tblCreditPending TVP_BalanceList  

	DECLARE @tmpInputTransId TABLE(TransId BIGINT, MainTransId BIGINT, MainStatusId TINYINT, SubStatusId TINYINT, Refno BIGINT)

	CREATE TABLE #BeforeUpd (custid INT, balance MONEY)  
	CREATE TABLE #AfterUpd(custid INT, balance MONEY)  
	CREATE TABLE #tmpSubTransId (RowId INT IDENTITY(1,1), TransId BIGINT, Refno BIGINT)
	CREATE TABLE #tmpMainTransId (TransId BIGINT, Refno BIGINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90101
	SET @SB_Error = 0

	SELECT	@RowId = 0
			,@strSubTransId = ''
			,@strMainTransId = ''
			,@strRefno = ''

	SELECT	@MatchDate = eventdate
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchId

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	val AS TransId
	FROM	dbo.f_SplitString(@TransIds, ',')
	OPTION (maxrecursion 0)

	UPDATE t 
		SET MainTransId = b.transid
			,MainStatusId = b.statusID
			,SubStatusId = bm.statusID
			,refno = b.refno
	FROM	@tmpInputTransId t 
		INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK)
			ON t.TransId = bm.transid
		INNER HASH JOIN dbo.bettrans b WITH(NOLOCK)
			ON	bm.refno = b.refno
				AND b.matchid = 29
				AND b.bettype = 29

	INSERT INTO #tmpSubTransId(TransId, Refno)
	SELECT	TransId, Refno
	FROM	@tmpInputTransId
	WHERE	MainTransId IS NOT NULL 	
			AND SubStatusId NOT IN (101, 102)

	SET @RowCount = @@ROWCOUNT
	
	SELECT @FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(ISNULL(MainTransId, TransId) AS VARCHAR(30)), CAST(ISNULL(MainTransId, TransId) AS VARCHAR(30)))
	FROM	@tmpInputTransId
	WHERE	MainTransId IS NULL
			OR SubStatusId IN (101, 102)

	IF @RowCount = 0
	BEGIN
		SELECT @ErrCode = 100  
				,@ErrMsg = 'No parlay ticket found.'  

		RETURN
	END
	
	EXEC dbo.NAP_Admin_CheckingProcess  
		@isExistParlay   = 1  
		, @avaiableProcess  = @avaiableProcess OUTPUT  
		, @ErrCode   = @ErrCode OUTPUT  
		, @ErrMsg   = @ErrMsg OUTPUT  
  
	IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
	BEGIN	
		SELECT @FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(ISNULL(MainTransId, TransId) AS VARCHAR(30)), CAST(ISNULL(MainTransId, TransId) AS VARCHAR(30)))
		FROM	@tmpInputTransId

		RETURN  
	END

	SET @FailedTransIds = ''

	-- BackUp bettransm tickets into zzzbettrans  
	INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
			winlost, livehomescore, liveawayscore, liveindicator, betteam, creator , refno,   
			winlostdate, betfrom, betcheck, checktime, matchid, bettype
	)  
	SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,  
			b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,  
			b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype
	FROM	#tmpSubTransId t
		INNER JOIN dbo.bettransm AS b WITH (NOLOCK)  
			ON	b.transid = t.TransId

	-- BackUp tickets of bettransm  
	INSERT INTO zzzbettransm (transid, custid, transdate, oddsid, hdp1, hdp2, odds, stake, status,   
				winlost, livehomescore, liveawayscore, liveINdicator, betteam, creator , refno,   
				winlostdate, betfrom, betcheck, checktime, matchid, bettype, VoidingHistoryId)  
	SELECT	b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status,   
			b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno,   
			b.winlostdate, b.betfrom, b.betcheck, b.checktime, b.matchid, b.bettype, @VoidingHistoryId
	FROM	#tmpSubTransId t
		INNER JOIN dbo.bettransm AS b WITH (NOLOCK)  
			ON	t.transid = b.transid   

	WHILE(@RowId <= @RowCount)
	BEGIN
		SET @strSubTransId = ''
		
		SELECT	@strSubTransId = @strSubTransId + CONVERT(VARCHAR(20), TransId) + ','
		FROM	#tmpSubTransId
		WHERE	RowId BETWEEN @RowId AND @RowId + 100
		
		EXEC dbo.NAP_Admin_Calculate_MP_broker @matchid = @matchId  
			,@fth = 0  
			,@fta = 0  
			,@hth = 0  
			,@hta = 0  
			,@matchdate = @matchdate  
			,@mode = 'VOID'  
			,@VoidTransID = @strSubTransId  
			,@UserId = @UserId

		SET @RowId = @RowId + 100
	END

	INSERT INTO #tmpMainTransId(TransId, Refno)
	SELECT	DISTINCT b.transid, b.refno
	FROM	#tmpSubTransId t
		INNER HASH JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.Refno = b.refno
	WHERE	b.matchid = 29
			AND b.statusID NOT IN (101, 102)

	SELECT	@strMainTransId = @strMainTransId + CONVERT(VARCHAR(20), TransId) + ','
			,@strRefno = @strRefno + ',' + CONVERT(VARCHAR(20), Refno) + '|' + CONVERT(VARCHAR(20), TransId)
	FROM	#tmpMainTransId

	EXEC dbo.NAP_Admin_Calculate_MP_broker   
		@matchid = @matchid  
		,@matchdate = @matchdate  
		,@strXML = @strMainTransId  
		,@mode  = 'PRECAL-29'  		

	INSERT INTO #BeforeUpd(custid, balance)
	SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM	#tmpMainTransId t
		INNER JOIN dbo.bettrans b WITH(ROWLOCK)
			ON t.TransId = b.transid
	GROUP BY b.custid
	
	EXEC dbo.NAP_Admin_Calculate_MP_broker   
		@matchdate = @matchdate  
		,@strXML = @strRefno  
		,@mode  = '29'  

	INSERT INTO #AfterUpd(custid, balance)
	SELECT	b.custid, SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
	FROM	#tmpMainTransId t
		INNER JOIN dbo.bettrans b WITH(ROWLOCK)
			ON t.TransId = b.transid
	GROUP BY b.custid

	INSERT INTO @tblCreditPending (custID, balance)  
	SELECT	a.custid  
			,(a.balance - b.balance) AS Balance  
	FROM	#BeforeUpd b  
		INNER JOIN #AfterUpd a 
			ON	a.custid = b.custid  
	WHERE	(a.balance - b.balance) > 0  
		 
	IF @@rowcount <> 0  
		EXEC dbo.Dot_BalancePendingCreditIns   
			@BalancePending = @tblCreditPending  
			,@Type   = 1 -- Sports  

	INSERT INTO @tblDebitPending (custID, balance)  
	SELECT	a.custid  
			,ABS(a.balance - b.balance) AS Balance  
	FROM	#BeforeUpd b  
		INNER JOIN #AfterUpd a 
			ON	a.custid = b.custid  
	WHERE	(a.balance - b.balance) < 0  
		 
	IF @@rowcount <> 0  
		EXEC dbo.Dot_BalancePendingDebitIns   
			@BalancePending = @tblDebitPending  
			,@Type   = 1 -- Sports  

	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(a.custid AS VARCHAR(20)) + ','
	FROM	#BeforeUpd b
		INNER JOIN #AfterUpd a
			ON b.custid = a.custid
	WHERE	b.balance > a.balance

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	EXEC dbo.NAP_Admin_CheckingProcess  
		@isExistParlay  = 1  
		, @IsReleased  = 1 

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ ' Parlay ticket with TransId: ' + @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO

