/*<info serverAlias="DBTXN-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_SingleType_Update]
	@RequestId			INT
	,@MatchId			INT
	,@VoidingHistoryId	INT
	,@TransIds			VARCHAR(MAX)
	,@UserId			INT
	,@IP				VARCHAR(50)		= ''
	,@IssueTypeId		TINYINT = 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@FailedTransIds	VARCHAR(MAX)	= NULL	OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = NULL	OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX) = NULL	OUTPUT

AS
/*	Created by: 20181212@Kathy
	Task: void single ticket [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190419@Kathy: Change KeyId = 6 for FastMarket and send notification in case of void all marked ticket [Redmine:#108826]
		- 20190605@Kathy: Add keyId = 5 for BetBuilder [Redmine:#106898]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200210@Helen: Hotfix - cashout - not insert 914 [Redmine:#128190]
		- 20200303@Charles: Copy 'epositiontaking' value from translog into bettrans [128921]
		- 20200609@Charles: Remove notify when void tickets [131865]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210206@Max: TVS - Lock TempVariableNumber and can't void cash out ticket [Redmine: #150176]
		- 20210207@Helen: Increase Retry for void process [Redmine: #150178]
		- 20210208@Max: [TVS] Enhance performance of void abnormal account [Redmine: #150204]
		- 20210225@July: HotFix - Update balance CO wrong wallet [Redmine: #150621]
		- 20210401@Kathy:  Enhance Auto Void Retry process [Redmine:#152581]
		- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
		- 20210601@July: TVS - Abnormal Account - Update Min/MaxWinlostdate into dbo.TicketVoiding_VoidingHistory [Redmine:#152175]
		- 20210622@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210722@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]
		- 20210804@Max: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
		- 20210922@Max: [TVS] Max payout phase 2 - [Redmine: #161658]
		- 20211115@Max: [TVS] Void abnormal bet of parlay [Redmine: #161337]
		- 20211122@Max: Hot fix - TVS insert CustLimitBetQueue when void CO ticket [Redmine: #164966]
		- 20211207@July: Implement New Cash Out Model [Redmine: #165097]
		- 20220110@Max: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220119@Max: Fix Issue - Include into feature split transfer [Redmine: #165093]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220404@Max: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
		- 20220518@July: [TVS] Update ChangeDate of CashoutSelling [Redmine: #172543]
		- 20220615@Max: [TVS] Some minor enhancements [Redmine: #173229]
		- 20220812@Max: MPO - [TVS] wrong data insert into CustLimitBetQueue when transid list include both single and parlay ticket [Redmine: #176578]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230201@Max: [TVS] Separate Sync Log table for SB and Non-Sports [Redmine: #179183]
		- 20230220@Max: [TVS] Change of TVS regarding to Scale out DBTrans for Credit - Split 789y Site [Redmine: #182803]
		- 20230517@Max: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20230707@July: Remove unnecessary code [Redmine: #190859]
		- 20230712@Max: Scale out credit - Fix issue child match cricket [Redmine: #181595]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240822@Max: [TVS] Integrate new bet type of Baseball AiO - Phase 2 [Redmine: #209441]

	Param's explanation:	
		Note: Retry lock single: 5s*16 = 90s(1p30s), Retry lock parlay: 20s*16 = 320s(5p)
		
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@Movebetdate		DATETIME
			,@MatchDate			DATETIME
			,@ThreadHold				INT = 0-- over threadhold, the parlay process will be locked in systemsetting 
			,@totalMainParlay			INT = 0
			,@IsAbnormalMixParlay		BIT = 0
			,@strTransCashout			VARCHAR(MAX) = ''
			,@xmlCashoutTicket			XML
			,@MainParlay_MaxPO			VARCHAR(MAX) = NULL
			,@avaiableProcess			BIT
			,@isExistFM					BIT = 0
			,@isExistFM2				BIT = 0
			,@IsExistBB					BIT = 0
			,@isExistMatch				BIT = 0
			,@xmlTransId				VARCHAR(MAX)
			,@session					NVARCHAR(50)
			,@CustIds					VARCHAR(MAX)
			,@isExistParlay				BIT = 0
			,@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistOutright			BIT = 0
			,@isExistNG					BIT = 0
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
			,@IsExistVS3 				BIT = 0
			,@IsExistParlayVS4 			BIT = 0
			,@IsExistVS4 				BIT = 0
			,@isExistMatch3rd			BIT = 0
			,@avaiableProcessRefNo		BIT
			,@ErrCodeRefNo				BIT = 0
			,@ErrMsgRefNo				VARCHAR(300) = '' 
			,@limitsecond				INT	= 180
			,@StartTime_Retry			DATETIME
			,@SitedbgroupId				SMALLINT 
			,@IsSiteDB					BIT
			,@TransInfo					VARBINARY(MAX)
			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	DECLARE @tmpInputTransId TABLE(TransId BIGINT)
	DECLARE @tblTransId_MoveBet TABLE (MatchId INT, TransId BIGINT)
						
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)

	CREATE TABLE #tmpTransId (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,actual_stake		MONEY
		,refcode			BIGINT
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
		,winlostdate		SMALLDATETIME
		,eventdate			DATETIME
		,isFinish			BIT
		,srecommend			INT
		,ruben				TINYINT
		,MainMatchId		INT
	)

	CREATE TABLE #balanceGameBefore (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #balanceGameAfter (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	DECLARE @tmpTransInfo TABLE(matchid INT, transid BIGINT, status NVARCHAR(10), winlost MONEY)

	DECLARE @tmpTransIdBatch TABLE (
		TransId				BIGINT
		,betid				BIGINT
		,Refno				BIGINT
		,actual_stake		MONEY
		,betdaqid			BIGINT
	)

	DECLARE @CashoutTickets_tmp AS TABLE (TransID BIGINT,custid INT, winlost MONEY, actual_stake MONEY, playercomm MONEY, bonusId INT, WalletType TINYINT, status VARCHAR(20))
	DECLARE @tmpTrans_beforeUpd AS TABLE (transid BIGINT,custid INT, Balance MONEY, Bonusid INT, WalletType TINYINT, betdaqid BIGINT)

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
		SET @IsSiteDB = 1

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()


	SET @StartTime = GETDATE()
	SET @LogActionId = 90100
	SET @SB_Error = 0

	SET @session = CAST(NEWID() AS NVARCHAR(50))
	SET @IsAbnormalMixParlay = CASE WHEN @IssueTypeId IN (11, 13) AND @MatchId = 29 THEN 1 ELSE 0 END
	SET @FailedTransIds = NULL

	INSERT INTO @tmpInputTransId (TransId)
	SELECT	value AS TransId
	FROM	STRING_SPLIT(@TransIds, ',')

	SELECT 	@MatchDate = eventdate
	FROM dbo.match WITH(NOLOCK)
	WHERE matchid = @MatchId
		
	INSERT INTO #tmpTransId(TransId, custid, bettype, KeyId, betdaqid, extrainfo, refcode, betid, matchid, oddsid, winlostdate, Refno, srecommend, ruben)
	SELECT	b.transid, b.custid, b.bettype
			,CASE 
				WHEN b.bettype = 38 THEN 5
				WHEN f.GroupId = 1 THEN 6 
				WHEN f.GroupId = 2 THEN 7
				ELSE 1 				
			END AS KeyId
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
			,b.matchid, b.oddsid
			,b.winlostdate, b.refno
			,b.srecommend
			,b.ruben
	FROM	@tmpInputTransId t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.bettype
			)f
	WHERE	b.statusID <> 102	
		AND b.SiteDBGroupID = @SitedbgroupId

	IF NOT EXISTS (SELECT TOP(1) 1 FROM #tmpTransId)
	BEGIN
		SELECT	@ErrCode = 100
				,@ErrMsg = 'No ticket found.'				

		RETURN
	END

	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))))
	BEGIN
		UPDATE	b
		SET sporttype 	= m.sporttype
			,eventdate = m.eventdate
			,MainMatchId = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN m.ParentID ELSE b.matchid END
		FROM	#tmpTransId b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		
		WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
			
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET sporttype	= l.sporttype
			,eventdate = o.eventdate
		FROM	#tmpTransId b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
			
		WHERE bettype IN (10)
	END
	
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET sporttype 	= r.sporttype
			,eventdate = o.EventDate	
		FROM	#tmpTransId b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END

	-- UPDATE Sportype for VS5
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransId WHERE bettype BETWEEN 11050 AND 11099))
	BEGIN
		UPDATE d
		SET  sporttype 	= m.SportType
			,eventdate  = m.EventDate
		FROM #tmpTransId d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
	END

	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #tmpTransId b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	IF EXISTS (SELECT 1 FROM #tmpTransId WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)))
	BEGIN
		UPDATE #tmpTransId
		SET eventdate = winlostdate
		WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))	
	END

	-- remove un-supported sports & bettype
	DELETE bd
	FROM #tmpTransId bd
	WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT

	IF @IssueTypeId IN (11,13) AND EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE Eventdate <= @Movebetdate)
	BEGIN	
		DELETE 
		FROM #tmpTransId
			OUTPUT	DELETED.matchid, DELETED.TransId
			INTO  @tblTransId_MoveBet (Matchid, TransId)
		WHERE eventdate <= @Movebetdate

		SET @MoveBetMatchIds = CAST((SELECT DISTINCT t.MatchId "@MatchId"
									  , CASE WHEN t.MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN  STUFF(ts.TransIds,1,1,'') ELSE NULL END "@TransIds"
								FROM @tblTransId_MoveBet t
									OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
													FROM @tblTransId_MoveBet s
													WHERE s.MatchId = t.MatchId AND t.MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
													FOR XML PATH('')
												)ts	 (TransIds)
								FOR XML PATH('r'), ROOT('root')
								) AS VARCHAR(MAX))
	END

	IF (@IssueTypeId NOT IN (1,10,3,4,5,6,7) AND @MatchDate <= @Movebetdate)
		OR (@IssueTypeId IN (11,13) AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId)) 
	BEGIN   
		SELECT	@ErrCode = 99
				,@ErrMsg = 'Match is under Movebet process, could not void ticket.'
		RETURN
	END

	IF @MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1) AND bettype <> 2799)
	BEGIN
		SET @isExistParlay = 1

		INSERT INTO #tblMatchParlayProcess (matchId, RefNo)
		SELECT @MatchId, refno
		FROM #tmpTransId
		WHERE matchid = @MatchId

		SET @totalMainParlay = @@ROWCOUNT

		EXEC dbo.NAP_Set_GlobalSettingSel 
				@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT
	END
	ELSE
	BEGIN
		SELECT @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
				,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
				,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
				,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
				,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
				,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
				,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
				,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
				,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
				,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
				,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
				,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
				,@IsExistVS3				= MAX (CASE WHEN bettype BETWEEN 5302 AND 5399 THEN 1 ELSE 0 END)
				,@IsExistParlayVS4			= MAX (CASE WHEN fs.SpcialBettypes IS NOT NULL THEN 1 ELSE 0 END)
				,@IsExistVS4				= MAX (CASE WHEN sporttype = 188 THEN 1 ELSE 0 END)
				,@isExistMatch3rd			= MAX (CASE WHEN sporttype = 147 THEN 1 ELSE 0 END)
		FROM	#tmpTransId b
			OUTER APPLY (
						SELECT GroupId
						FROM dbo.f_TVS_CheckingProcessGroupBettypes()
						WHERE Bettype = b.Bettype
				)f
			OUTER APPLY (
					SELECT Bettype AS SpcialBettypes
						FROM dbo.f_TVS_SpeciallyBettypes() f
						WHERE TypeId IN (1) 
							AND f.bettype <> 2799
							AND b.bettype = f.bettype
				)fs

		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT matchid, KeyID
		FROM #tmpTransId

		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT DISTINCT matchid
			, CASE 
				WHEN Bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes()) 
						AND Bettype NOT BETWEEN 801 AND 899
						AND f.GroupId IS NULL
						AND Bettype NOT IN (1231,1232,1233)
					THEN 1 --SB,NG,LC
				WHEN Bettype = 10 THEN 2	-- Outright
				WHEN Bettype BETWEEN 801 AND 899 THEN 3 -- MG
				WHEN f.GroupId = 1 THEN 6 -- FM
				WHEN Bettype IN (1231,1232,1233) THEN 4 -- VS Racing
				WHEN Bettype = 38 THEN 5 -- Bet Builder
				WHEN f.GroupId = 2 THEN 7 -- FM 228
				WHEN Bettype BETWEEN 11050 AND 11099 THEN 8 --VS5
				ELSE 0
			END AS KeyID
		FROM #tmpTransId b
			OUTER APPLY (
						SELECT GroupId
						FROM dbo.f_TVS_CheckingProcessGroupBettypes()
						WHERE Bettype = b.Bettype
				)f
	END
	
	--Retry lock match in 180s
	SET @StartTime_Retry= GETDATE()
	WHILE (1=1)
	BEGIN
		SELECT @ErrCode = 0
			,@ErrMsg = ''

		IF DATEDIFF(SECOND, @StartTime_Retry, getdate()) > @limitsecond
		BEGIN
			SELECT	@ErrCode = 1000000
					,@ErrMsg = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'

			RETURN;
		END

		IF @isExistParlay = 1 OR @IsExistParlayVS4 = 1
		BEGIN
			-- Apply new way to lock parlay tickets	
			IF @totalMainParlay <= @ThreadHold
			BEGIN
				-- checking Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno	= @isExistParlay
					,@IsLockingByRefnoVS		= @IsExistParlayVS4
					,@spName			= @spName
					,@Session			= @Session
					,@avaiableProcess 	= @avaiableProcessRefNo OUTPUT
					,@ErrCode			= @ErrCodeRefNo OUTPUT
					,@ErrMsg			= @ErrMsgRefNo OUTPUT

				IF @avaiableProcessRefNo = 0 OR @ErrCodeRefNo <> 0
					CONTINUE
				ELSE 
					BREAK	
			END
			ELSE --@totalSubParlay > 10K
			BEGIN
				EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 			= @isExistParlay
					, @IsLockingByRefnoVS		= @IsExistParlayVS4
					,@avaiableProcess 		= @avaiableProcess OUTPUT
					,@ErrCode				= @ErrCode OUTPUT
					,@ErrMsg				= @ErrMsg OUTPUT

				IF @avaiableProcess = 0 OR @ErrCode <> 0
					CONTINUE
				ELSE 
					BREAK
			END
		END
		ELSE
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright 			= @isExistOutright
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @isExistMatch
				, @isExistNG				= @isExistNG
				, @isExistVS				= @isExistVS
				, @isExistBB				= @isExistBB
				, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				, @isExistFM2				= @isExistFM2
				, @isExistMatch3rd			= @isExistMatch3rd
				, @spName					= @spName
				, @avaiableProcess 			= @avaiableProcess OUTPUT
				, @ErrCode					= @ErrCode OUTPUT
				, @ErrMsg					= @ErrMsg OUTPUT
			
			IF @avaiableProcess = 0 OR @ErrCode <> 0
					CONTINUE
				ELSE 
					BREAK
		END
	END

	SELECT	@FailedTransIds = COALESCE(@FailedTransIds + ',' + CAST(it.TransId AS VARCHAR(30)), CAST(it.TransId AS VARCHAR(30)))
	FROM	@tmpInputTransId it
	WHERE	NOT EXISTS (SELECT TOP(1) 1 FROM #tmpTransId c WHERE c.TransId = it.TransId)
			AND 1 = CASE WHEN @IssueTypeId <> 13 THEN 1 
						 WHEN @IssueTypeId = 13 AND NOT EXISTS (SELECT TOP 1 1 FROM @tblTransId_MoveBet m WHERE m.TransId = it.TransId) THEN 1
						 ELSE 0 END

	--Get data before update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @IsExistVS3 = 1 OR @IsExistVS4 = 1 OR @isExistMatch3rd = 1)
	BEGIN
		INSERT INTO #balanceGameBefore(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				ELSE 1201
			END AS groupId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 1201 AND 1299
			OR b.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 5302 AND 5399 --VS3 (Leap Gaming)
			OR b.bettype BETWEEN 10400 AND 10449 --VS4 (Edge Gaming)
			OR b.bettype BETWEEN 11050 AND 11099 --VS5
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				ELSE 1201
			END
	END
	
	--Insert tmp table for correct balance CO
	INSERT INTO @tmpTrans_beforeUpd (transid,custid, Balance,Bonusid, WalletType, betdaqid)
	SELECT main.transid,main.custid
		, main.winlost - main.actual_stake + playercomm as balance
		,BonusID = CASE WHEN main.BonusID > 0 AND main.WalletType = 1 THEN main.BonusID ELSE 0 END
		,WalletType = ISNULL(main.WalletType, 2) -- Cash Wallet as default
		,main.betdaqid
	FROM	dbo.bettrans main WITH (NOLOCK)
		INNER JOIN #tmpTransId t ON t.TransId = main.transid
	
	--capture balance before voiding
	INSERT INTO @BeforeUpd(
		matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	)
	SELECT	b.matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	t.matchid
				,b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
				,b.Balance AS balance
		FROM	#tmpTransId t
			INNER JOIN @tmpTrans_beforeUpd b
				ON	t.TransId = b.transid
	)b
	GROUP BY b.matchid
			,b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType
	
	WHILE (1=1)
	BEGIN
		DELETE @tmpTransIdBatch

		SET @xmlTransId = ''
		SET @strTransCashout = ''
		DELETE @CashoutTickets_tmp

		UPDATE TOP(2000) t
			SET t.isFinish = 1
		OUTPUT deleted.TransId
			,deleted.Refno
			,deleted.betid
			,deleted.actual_stake
			,b.betdaqid
		INTO @tmpTransIdBatch(TransId, Refno, betid, actual_stake, betdaqid)
		FROM #tmpTransId t
			INNER JOIN @tmpTrans_beforeUpd b ON b.transid = t.TransId
		WHERE t.isFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		-- backup into zzzbettrans
		INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2
				,odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator  
				,betteam, creator, refno, winlostdate, betfrom
				,betcheck
				,comstatus
				,checktime, matchid, bettype  
				,VoidingHistoryId
				,SiteDBGroupID
				,RepUpdateTime
			)  
		SELECT b.transid, b.custid, GETDATE(), b.oddsid, b.hdp1, b.hdp2
			,b.odds, b.stake, b.STATUS, b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator
			,b.betteam, b.creator,b.refno, b.winlostdate, b.betfrom
			,b.betcheck 
			,b.comstatus
			,b.checktime, b.matchid, b.bettype  
			,@VoidingHistoryId
			,b.SiteDBGroupID
			,SYSDATETIME()
		FROM @tmpTransIdBatch AS t
			INNER JOIN dbo.bettrans b WITH (NOLOCK)  
				ON b.transid = t.TransId

		SELECT @xmlTransId = (SELECT	t.TransId AS '@transid'
										,t.betid AS '@betid'
										,t.betdaqid AS '@betdaqid'
								FROM	@tmpTransIdBatch t
								FOR XML PATH('r'), ROOT('root')
							)	
						
		EXEC dbo.TicketVoiding_Admin_VoidingTransId 
			@TransIds = @xmlTransId
			,@UserId = @UserId
			,@IssueTypeId = @IssueTypeId
			,@IsAbnormalMixParlay = @IsAbnormalMixParlay
			,@strTransCashout = @strTransCashout OUTPUT

		-- Adjust BL before for affected cashout tickets
		IF @strTransCashout <> ''
		BEGIN
			SET @xmlCashoutTicket = CONVERT(XML, @strTransCashout)
					
			INSERT INTO @CashoutTickets_tmp(transid, custid, winlost, actual_stake, playercomm, bonusId, WalletType, status)
			SELECT T.C.value('./@t', 'BIGINT') 		AS transid
					, T.C.value('./@c', 'INT') 	AS custid
					,T.C.value('./@wl', 'MONEY') 	AS winlost
					,T.C.value('./@al', 'MONEY') 	AS actual_stake
					,T.C.value('./@pl', 'MONEY') 	AS playercomm
					,T.C.value('./@bn', 'INT') 	AS bonusid
					,T.C.value('./@w', 'TINYINT') 	AS WalletType
					,T.C.value('./@st', 'VARCHAR(20)') 	AS status
			FROM @xmlCashoutTicket.nodes('/b') AS T(C)
			OPTION (OPTIMIZE FOR (@xmlCashoutTicket = NULL ))
					
			UPDATE bf
				SET balance = bf.balance - bl.balance_old + bl.balance_new
			FROM @BeforeUpd bf
				INNER JOIN  (
							SELECT	c.custid,c.BonusID,c.WalletType, SUM(c.balance) AS balance_old, SUM(tmp.winlost - tmp.actual_stake + tmp.playercomm) AS balance_new
							FROM  @CashoutTickets_tmp tmp 
									INNER JOIN @tmpTrans_beforeUpd C ON c.TransID = tmp.transid AND tmp.custid = c.custid
							GROUP BY c.custid,c.BonusID,c.WalletType							
						) AS bl ON bl.custid = bf.custid AND bf.bonusId =  bl.BonusID AND bf.walletType = bl.WalletType

			--Correct data captured before because CO happen when voiding ticket
			UPDATE b
			SET  b.actual_stake = t.actual_stake
				, b.betdaqid = -2
			FROM #tmpTransId b 
				INNER JOIN @CashoutTickets_tmp t ON t.transid = b.transid
			WHERE ISNULL(b.betdaqid, 0) <> -2

			UPDATE z
			SET z.status = t.status
				, z.winlost = t.winlost
			OUTPUT deleted.matchid, deleted.transid, t.status, t.winlost
			INTO @tmpTransInfo (matchid, transid, STATUS, winlost)
			FROM zzzbettrans z WITH (ROWLOCK, UPDLOCK)
				INNER JOIN @CashoutTickets_tmp t ON t.transid = z.transid
			WHERE z.status <> t.status

			IF @IsSiteDB = 1
			BEGIN

				SET @transInfo = COMPRESS((
					SELECT	transId AS 't'
							, matchid AS 'mid'
							, STATUS AS 's'
							, winlost AS 'w'
					FROM	@tmpTransInfo WHERE matchid = @MatchId 
					FOR JSON PATH))

				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, Action, MatchId, TransInfoJson, TicketType)
				SELECT 'TVS', 'Void', 'zzzbettrans', 'U', @matchid, @transInfo, 's' 
			END
		END
	END

	--Get data after update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @IsExistVS3 = 1 OR @IsExistVS4 = 1 OR @isExistMatch3rd = 1)
	BEGIN
		INSERT INTO #balanceGameAfter(custid, winlostdate, balance, winlost, gametypeid, groupid)
		SELECT b.custid, b.winlostdate
			, SUM(b.winlost - b.actual_stake)
			, SUM(CASE WHEN b.ruben = 1 THEN b.winlost - b.actual_stake ELSE 0 END)
			,b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				ELSE 1201
			END
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR tmp.bettype BETWEEN 81 AND 120 OR tmp.bettype BETWEEN 8101 AND 8120
			OR tmp.Bettype BETWEEN 1201 AND 1299
			OR tmp.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 5302 AND 5399 --VS3 (Leap Gaming)
			OR b.bettype BETWEEN 10400 AND 10449 --VS4 (Edge Gaming)
			OR b.bettype BETWEEN 11050 AND 11099 --VS5
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				ELSE 1201
			END
	END

	INSERT INTO @AfterUpd(
		matchid
		,custid
		,balanceType		
		,walletType
		,bonusId
		,balance
	)
	SELECT	b.matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	t.matchid
				,b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,ISNULL(b.WalletType, 2) AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
	)b
	GROUP BY b.matchid
			,b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--UPDATE balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd
			, @ActionId				= 0	

	-- Update CashOutSelling [#165097]
	UPDATE c
	SET CashOutStatus = 6 --Void
	   ,ChangeDate = GETDATE()
	FROM dbo.CashOutSelling c WITH (ROWLOCK, UPDLOCK)
		INNER JOIN #tmpTransId b ON c.TransID = b.transid AND c.MatchID = b.matchid
	WHERE b.betdaqid = -2 

	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @IsExistVS3 = 1 OR @IsExistVS4 = 1 OR @isExistMatch3rd = 1)
	BEGIN	
		CREATE TABLE #balanceGameChange (
			custid 			INT
			,winlostdate 	SMALLDATETIME
			,balance 		MONEY
			,bettype		SMALLINT
			,gametypeid		SMALLINT			
			,Increased 		BIT
		)

		INSERT INTO #balanceGameChange (custid, winlostdate, balance, bettype, gametypeid, Increased)
		SELECT	b.custid
				,b.winlostdate
				,a.winlost - b.winlost
				,a.groupid
				,a.gametypeid
				,CASE WHEN a.winlost > b.winlost THEN 1 ELSE 0 END
		FROM	#balanceGameBefore b
			INNER JOIN #balanceGameAfter a 
				ON	b.custid 		= a.custid
				AND b.winlostdate 	= a.winlostdate
				AND a.gametypeid = b.gametypeid
				AND a.groupid = b.groupid
		WHERE	b.winlost <> a.winlost
		
		INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,ABS(balance)
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 0

		INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,balance
				,bettype
				,GameTypeID
		)
		SELECT	custid
				,winlostdate
				,balance
				,bettype
				,gametypeid
		FROM	#balanceGameChange
		WHERE	Increased = 1
		
		DROP TABLE #balanceGameChange
	END

	IF @isExistParlay = 1 OR @IsExistParlayVS4 = 1
	BEGIN
		IF @totalMainParlay <= @ThreadHold
		BEGIN
			------ releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = @isExistParlay
				,@IsLockingByRefnoVS		= @IsExistParlayVS4
				,@Session	= @Session
				,@IsReleased = 1	
		END
		ELSE IF @totalMainParlay > @ThreadHold
		BEGIN
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay 				= @isExistParlay
				,@IsLockingByRefnoVS		= @IsExistParlayVS4
				, @IsReleased				= 1
		END
	END
	ELSE
	BEGIN
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistOutright 			= @isExistOutright
			, @isExistFM				= @isExistFM
			, @isExistMatch				= @isExistMatch
			, @isExistNG				= @isExistNG
			, @isExistVS				= @isExistVS
			, @isExistBB				= @isExistBB
			, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
			, @isExistFM2				= @isExistFM2
			, @isExistMatch3rd			= @isExistMatch3rd
			, @IsReleased				= 1
	END
		
	----------------Insert Max Payout Queue----------------
	DECLARE @TransIds_MaxPO VARCHAR(MAX) = '', @sporttype SMALLINT = NULL

	IF @MatchId NOT IN (9,29) 
	BEGIN
		SET @sporttype = (SELECT DISTINCT m.sporttype FROM #tmpTransId m WITH (NOLOCK) WHERE m.MainMatchId = @MatchID)
		SELECT @TransIds_MaxPO = (SELECT b.CustId AS '@custid'
					,CASE 
						WHEN dp.custid IS NOT NULL THEN 3 --deposit 
						WHEN s.SiteLabel = '789y' THEN 2 --789y
						ELSE 1 END AS '@sitetype'
					,b.TransId AS '@transid'
					,b.bettype AS '@bettype'
				FROM #tmpTransId b
					INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = b.custid
					INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = c.site
					LEFT JOIN CustDB.dbo.Dep_CustSuper dp WITH (NOLOCK) ON b.srecommend = dp.custid
				WHERE b.MainMatchId = @MatchId AND b.sporttype = @sporttype AND b.bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
				FOR XML PATH('r'), ROOT('root')
			)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Void
			@MatchId = @MatchId
			,@sporttype = @sporttype
			,@TransidList = @TransIds_MaxPO
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId WHERE bettype = 29)
	BEGIN
		--Prepare for Max Payout
		SELECT @MainParlay_MaxPO = (SELECT t.custid AS '@custid'
									,t.ruben AS '@ruben'
									,t.transid AS '@transid'
								FROM #tmpTransId t
								WHERE t.bettype = 29
								GROUP BY custid, ruben, transid
								FOR XML PATH('r'), ROOT('root')
							)

		EXEC dbo.NAP_Admin_CustLimitBetQueue_Insert_Parlay
			@MatchId= 29
			,@TransidList = @MainParlay_MaxPO
	END
	-------------------------------------------------------
	
	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	(
		SELECT DISTINCT b.custid
		FROM @BeforeUpd b
			INNER JOIN @AfterUpd a
				ON b.custid = a.custid
					AND b.matchid = a.matchid
					AND b.balanceType = a.balanceType
					AND b.bonusId = a.bonusId
					AND b.walletType = a.walletType
		WHERE	b.balance > a.balance
	)t

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + CAST(@VoidingHistoryId AS VARCHAR(20))
								+ CASE WHEN @MatchId = 29 THEN  ' Main Parlay ticket with TransId: ' ELSE ' Single ticket with TransId: '  END + @TransIds
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #tblMatchProcess
	DROP TABLE #tmpTransId
	DROP TABLE #balanceGameAfter
	DROP TABLE #balanceGameBefore
	DROP TABLE #tblMatchParlayProcess
END

GO

