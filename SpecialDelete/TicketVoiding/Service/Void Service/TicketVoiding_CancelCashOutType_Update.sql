/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_CancelCashOutType_Update]
(
	 @RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)		= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
)	
AS
/* Created by: 20230221@July
	Task: [TVS] Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20230221@July: Create new SP [Redmine: #176998]
		- 20231215@Max: [TVS] Include negative balance member by cancel cash out action to email [Redmine: #196706]
		- 20250117@July: Enhance gap time between voiding by function and TVS [Redmine: #216667]
		- 20250117@July: Apply retry when cancelling cash out action [Redmine: #224848]
		- 20250617@July: [TVS] Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

	Explanation's Param:

*/
BEGIN	
	SET NOCOUNT ON
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@session			NVARCHAR(50) = CAST (NEWID() AS NVARCHAR(50))
			,@CustIds			VARCHAR(MAX)
			,@limitsecond		INT	= 180
			,@StartTime_Retry	DATETIME

	DECLARE @avaiableProcess 	BIT
		  , @Movebetdate		DATETIME
		  , @FCUpdateTime		DATETIME2
		  , @xmlTransId			VARCHAR(MAX) = ''
		  , @SiteDBGroupID		SMALLINT
		  , @transInfo			VARBINARY(MAX) 
		  , @ActionID			INT = 90999 --TVS - Agency Cash Service

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	SET @StartTime = GETDATE()
	SET @LogActionId = 90100
	SET @SB_Error = 0
	SET @FailedTransIds = NULL

	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	
	CREATE TABLE #tmpTransId (
		TransId				BIGINT,
		BetType				SMALLINT,
		Status				NVARCHAR(10),
		RefNo				BIGINT,
		BetdaqId			BIGINT,
		custid				INT,
		matchid				INT,
		awinlost			MONEY,
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportType			SMALLINT,
		EventDate			DATETIME,
		statuswinlost		TINYINT,
	)
	
	DECLARE @BeforeUpd 	TVP_BalanceChange
	DECLARE @AfterUpd 	TVP_BalanceChange
	CREATE TABLE #Balance (custid INT PRIMARY KEY, balance MONEY, Increased BIT)

	DECLARE @tmpInputTransId TABLE(TransId BIGINT)
	DECLARE @tmpTransInfo TABLE (transId BIGINT, matchId INT
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT, ruben TINYINT
		,FcUpdateTime DATETIME2,creator INT, betdaqid BIGINT, virtualrate FLOAT
	)
	
	INSERT INTO @tmpInputTransId (TransId)
	SELECT	value AS TransId
	FROM	STRING_SPLIT(@TransIds, ',')
		
	INSERT INTO #tmpTransId(
			TransId,
			BetType,
			Status,
			BetdaqId,
			custid,
			matchid,
			awinlost,
			HomeId,
			AwayId,
			LeagueId,
			SportType,
			EventDate,
			statuswinlost
			)
	SELECT 	b.TransId,
			b.BetType,
			b.Status,
			b.BetdaqId,
			b.custid,
			b.matchid,
			b.awinlost,
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype,
			m.eventdate,
			b.statuswinlost
	FROM @tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH(NOLOCK) ON t.TransId = b.transid
		INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = b.matchid
	WHERE	b.betdaqid = -2 
		AND b.statusID IN (103, 111, 112, 113)
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	IF NOT EXISTS( SELECT 1 FROM #tmpTransId)
	BEGIN
		SELECT @ErrCode = 100
			   ,@ErrMsg = 'No ticket found.'

		RETURN
	END

	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF EXISTS ( SELECT TOP 1 1 FROM #tmpTransId WHERE EventDate <= @Movebetdate )
	BEGIN
		SELECT @ErrCode = 99
			 , @ErrMsg = 'Match is under Movebet process, could not void ticket.'
				
		RETURN
	END
	
	SELECT	@FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(it.TransId AS VARCHAR(30)), CAST(it.TransId AS VARCHAR(30)))
	FROM	@tmpInputTransId it
	WHERE	NOT EXISTS (SELECT TOP(1) 1 FROM #tmpTransId c WHERE c.TransId = it.TransId)

	--> check and not allow attempt to void tickets of this match while it's being calculated
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid, 1 AS KeyID
	FROM #tmpTransId
		
	SET @StartTime_Retry = GETDATE()
	WHILE (1=1)
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = ''

		IF DATEDIFF(SECOND, @StartTime_Retry, getdate()) > @limitsecond
		BEGIN
			SELECT	@ErrCode = 1000000
					,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN;
		END

		EXEC dbo.NAP_Admin_CheckingProcess
			  @isExistMatch		= 1
			, @spName			= @spName
			, @avaiableProcess 	= @avaiableProcess OUTPUT
			, @ErrCode			= @ErrCode OUTPUT
			, @ErrMsg			= @ErrMsg OUTPUT

		IF @avaiableProcess = 0 OR @ErrCode <> 0
			CONTINUE
		ELSE 
			BREAK
	END
	
	--> backup cash-out transaction ticket
	INSERT INTO dbo.zzzbettrans (transid,custid,transdate,oddsid,hdp1,hdp2,odds,stake,status,
				winlost,livehomescore,liveawayscore,liveindicator,betteam,creator, refno, 
				winlostdate,betfrom,betcheck,checktime,matchid, bettype, comstatus, RepUpdateTime, SiteDBGroupID, VoidingHistoryId)
	SELECT  b.transid, b.custid, CURRENT_TIMESTAMP, b.oddsid, b.hdp1, b.hdp2, b.odds, b.stake, b.status, 
			b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator, b.betteam, b.creator , b.refno, 
			b.winlostdate, b.betfrom, @session AS betcheck, b.checktime, b.matchid, b.bettype, 'CO', SYSDATETIME(), b.SiteDBGroupID, @VoidingHistoryId
	FROM	dbo.bettrans b WITH(NOLOCK)
		INNER JOIN #tmpTransId s ON	s.transId = b.transid
	WHERE b.statusID NOT IN (101,102,103)

	--> capture before		
	INSERT INTO @BeforeUpd (custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId s
			ON s.transId = b.transid
		WHERE b.statusID NOT IN (101,102,103)
	) AS temp
	GROUP BY temp.custid
	
	/*1. Update to running for CO Transaction*/
	SET @FCUpdateTime = SYSDATETIME()
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
	SET		b.winlost = 0
			,b.awinlost = 0
			,b.mwinlost = 0
			,b.swinlost = 0
			,b.playercomm = 0
			,b.comm = 0
			,b.acomm = 0
			,b.scomm = 0
			,b.status = 'running'
			,b.statusID = 0
			,b.ruben = 0
			,b.creator = @UserId
			,b.betdaqid = -1
			,b.virtualrate = CASE WHEN c.VirtualRate = 0 THEN b.virtualrate ELSE c.VirtualRate END
			,b.FcUpdateTime  = @FCUpdateTime
		OUTPUT inserted.TransId, inserted.matchid, inserted.winlost, inserted.awinlost, inserted.mwinlost, inserted.swinlost, inserted.playercomm, inserted.comm, inserted.acomm
			, inserted.scomm, inserted.status, inserted.statusID, inserted.ruben, inserted.creator, inserted.betdaqid, inserted.virtualrate, inserted.FcUpdateTime
		INTO @tmpTransInfo (transId, matchId, WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, Comm, aComm, sComm, Status, StatusID, ruben, creator, betdaqid, virtualrate, FcUpdateTime)
	FROM	dbo.bettrans b 
		INNER JOIN #tmpTransId s ON	b.transid = s.transId
		INNER JOIN dbo.CashOutSelling c WITH (NOLOCK) ON b.transid = c.TransID		
	WHERE b.statusID NOT IN (101,102,103)

	SET @transInfo = COMPRESS((
	SELECT	b.transId AS 't'
			, b.winlost AS 'w'
			, b.awinlost AS 'aw'
			, b.mwinlost AS 'mw'
			, b.swinlost AS 'sw'
			, b.playercomm AS 'pc'
			, b.comm AS 'c'
			, b.acomm AS 'ac'
			, b.scomm AS 'sc'
			, b.status AS 's'
			, b.statusID AS 'sid'			
			, b.ruben AS 'r'
			, b.creator AS 'cr'
			, b.betdaqid AS 'bdaq'
			, b.virtualrate AS 'v'
			, b.FcUpdateTime AS 'rut'
	FROM	@tmpTransInfo b
	FOR JSON PATH))

	IF @SiteDBGroupID <> 0 AND @transInfo IS NOT NULL
	BEGIN
		INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
		SELECT 'TVS', 'Cancel_CO', 'bettrans', 'U', @MatchId, @transInfo, 's'
	END

	/*2. Re-Cal for CO Transaction already has statuswinlost*/
	SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
							FROM #tmpTransId t
							WHERE t.statuswinlost IS NOT NULL
							FOR XML PATH('r'), ROOT('root')
						)
	IF @xmlTransId <> ''
	BEGIN
		EXEC dbo.TicketVoiding_ReCalculate_Single_Update 
			@TransIds = @xmlTransId
	END

	--> capture after
	INSERT INTO @AfterUpd(custid, balance, balanceType)
	SELECT temp.custid
		, SUM(temp.balance) AS balance
		, 1 AS balanceType
	FROM (
		SELECT	b.custid
			, (b.winlost - b.actual_stake + b.playercomm) AS balance
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId s
			ON s.transId = b.transid							
	) AS temp
	GROUP BY temp.custid				
	
	--> compare BALANCE
	EXEC [dbo].[NAP_Admin_BalancePendingIns]
		@BeforeUpd	 = @beforeUpd
		, @AfterUpd	 = @afterUpd

	--Update CashoutSelling
	UPDATE s
	SET s.CashOutStatus = 6
		, s.CashoutExtraInfo = REPLACE(s.CashoutExtraInfo, '</root>', c.CashOutExtraInfo) + '</root>'
		, s.ChangeDate = CONVERT(DATETIME,@FCUpdateTime)
	FROM dbo.CashOutSelling s WITH (ROWLOCK, UPDLOCK)
		CROSS APPLY (
				SELECT N'<r ct=''' + CONVERT(VARCHAR(30),CONVERT(DATETIME,@FCUpdateTime),21) + ''' s=''6'' w=''0''/>' AS CashOutExtraInfo
				FROM #tmpTransId t
				WHERE t.TransId = s.TransID
			)c
	
	------ releasing SD process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1

	INSERT INTO #Balance (custid, balance, Increased)
	SELECT b.custid, SUM(a.balance - b.balance) AS balance, CASE WHEN SUM(a.balance) > SUM(b.balance) THEN 1 ELSE 0 END
	FROM @BeforeUpd b
		INNER JOIN @AfterUpd a ON b.custid = a.custid AND b.balanceType = a.balanceType
	WHERE b.balance <> a.balance
	GROUP BY b.custid

	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(custid AS VARCHAR(20)) + ','
	FROM #Balance
	WHERE Increased = 0

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	--> Add Agency Cash Service - Negative Balance into BalanceNegative table  [#225390]
	IF OBJECT_ID('BalanceNegative','U') IS NOT NULL AND @SiteDBGroupID = 3 --Credit
	BEGIN
		INSERT INTO [dbo].[BalanceNegative]
					([ExecDate]
					,[MatchID]
					,[ActionID]
					,[GroupID]
					,[CustID]
					,[Balance]
					,[StatusID]
					,[SessionId]
					,[Remark])
		SELECT	 GETDATE()
				,@MatchId
				,@ActionID
				,0		-- For Void/Recover
				,CustID
				,Balance
				,0
				,@session
				,@spName + ' - RequestId: ' + CAST(@RequestId AS VARCHAR)
		FROM	#Balance
		WHERE	Increased = 0
	END		        
	DROP TABLE #Balance

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ', VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ ', Cancel Cash-Out ticket with TransId: ' + @TransIds
								AS '@LogData'
							,@MatchId AS '@MatchId'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpTransId

	SET NOCOUNT OFF
END
GO