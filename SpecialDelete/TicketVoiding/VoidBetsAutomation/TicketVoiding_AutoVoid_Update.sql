/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_AutoVoid_Update]
	@MatchId		INT
	,@sporttype		SMALLINT = 1
	,@UserId		INT = 10278938
	,@UserName		VARCHAR(100) = 'starixIT'
	,@Action		VARCHAR(100) = NULL
	,@RequestID		INT  = 0
	,@IP			VARCHAR(50)		= '125.227.140.97'
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			VARCHAR(300)	= ''	OUTPUT
	,@VoidingHistoryIds VARCHAR(MAX) = '' OUTPUT
	,@NegativeBalanceUsers VARCHAR(MAX) = '' OUTPUT
	,@MoveBetMatchIds   VARCHAR(MAX) = NULL	OUTPUT
AS
/*	Created by: Helen
	Date 20200212
	Task: [TVS] Abnormal Void Bets Automation
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200212@Helen:[TVS] Abnormal Void Bets Automation [Redmine:#127398]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis + hotfix + VIP account [Redmine:#131516]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200609@Charles: Remove notify when void tickets [131865]
		- 20200625@Max: [TVS] Auto Void for remaining sports - [Redmine: #135574]
		- 20200727@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20201007@Max: Integrate new bet type Time Machine OU [Redmine: #143032]
		- 20201210@Max: TVS - New issue type Abnormal Accounts [Redmine: #143666]
		- 20210128@Max: Hotfix - TVS [Redmine: #149573]
		- 20210130@Max: TVS -Issue Lock Match Resettle [Redmine: #149743]
		- 20210201@Max: Hotfix - TVS - Abnormal Accounts [Redmine: #149697]
		- 20210225@July: HotFix - Update balance CO wrong wallet [Redmine: #150621]
		- 20210302@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210302@Max: TVS - Integrate Cricket AIO [Redmine: #150075]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210402@July: TVS - Auto void before KO time with 2 new action - [Redmine: #150522]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210508@Helen: TVS - Hotfix - Wrong ticket status displayed on bet list for voided Abnormal Bet tickets[Redmine: #154762]
		- 20210527@July: DB Enhancement for troubleshoot & Enhance SP for Lock Process [Redmine: #155678]
		- 20210106@July: TVS - Abnormal Account - Update Min/MaxWinlostdate into dbo.TicketVoiding_VoidingHistory [Redmine:#152175] 
		- 20210622@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20210720@July: TVS - Apply new way to lock parlay tickets [Redmine: #157970]

	Param's explanation:	
		
		
*/      
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT 
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT
			,@Void_cnt			INT = 0
			,@Recalculate_cnt	INT = 0
			,@TransIDList_tmp	VARCHAR(MAX)= ''
			,@VoidingHistoryIdList VARCHAR(MAX)= ''
			,@IsTest			BIT = 0
			,@LeagueGroupID		INT		
			,@LeagueId			INT
			,@HomeId			INT
			,@AwayId			INT
			,@KickOffTime	DATETIME	
			,@query NVARCHAR(MAX) = ''
			,@ExecuteSQL NVARCHAR(MAX) = ''
			,@IsActiveVoidWinning BIT = 0
			,@VoidDataXML       XML = NULL
			,@RequestDetailId	INT
			,@spName			VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@Movebetdate		DATETIME
			,@MatchId_cnt		INT = 0
			,@ThreadHold		INT = 0 -- over threadhold, the parlay process will be locked in systemsetting
			,@totalMainParlay	INT = 0

	DECLARE @avaiableProcess BIT
			,@isExistMatch BIT
			,@xmlTransId VARCHAR(MAX)
			,@session NVARCHAR(50)
			,@CustIds VARCHAR(MAX)
			,@CustBalance XML
			,@IssueTypeId	TINYINT
			,@CustIdsCashOut VARCHAR(MAX)
			,@isExistFM2				BIT = 0
			,@isExistMG BIT
			,@isExistFM BIT
			,@IsExistBB	BIT
			,@winlostdate				DATETIME
			,@isExistParlay				BIT = 0
			,@IsExistParlayVSBetradar 	BIT = 0
			,@IsExistVSBetradar 		BIT = 0
			,@isExistOutright			BIT = 0
			,@isExistNG					BIT = 0
			,@isExistBT					BIT = 0
			,@isExistCashOut			BIT = 0
			,@isExistCricket			BIT = 0
			,@isExistLC					BIT = 0
			,@isExistVS					BIT = 0
			,@Remark					VARCHAR (500) = ''
			,@isExistLucky3				BIT = 0
			,@Lucky3TransIDs			VARCHAR(MAX)
			,@Lucky3Matches				VARCHAR(MAX) = ''
	
	DECLARE @AutoVoid_InputRequest_tmp AS TABLE (RequestID INT)
	DECLARE @AutoVoid_ValidRequest AS TABLE (RequestID INT, Transids VARCHAR(MAX), IssueTypeId TINYINT, MinWinlostdate DATETIME, MaxWinlostdate DATETIME)
	DECLARE @VoidingHistory_tmp AS TABLE (RequestID INT, VoidingHistoryId INT, IssueTypeId TINYINT)
			
	DECLARE @BeforeUpd TVP_BalanceWalletChange
	DECLARE @AfterUpd  TVP_BalanceWalletChange

	CREATE TABLE #inputRequestTransId (TransId BIGINT, RequestID INT, IssueTypeId TINYINT, RequestType TINYINT, DecidedBy NVARCHAR(200), ActionId TINYINT)
	DECLARE @tmpInputTransId_VOID TABLE(TransId BIGINT, RequestID INT, IssueTypeId TINYINT, DecidedBy NVARCHAR(200), Winlostdate DATETIME, StatusId TINYINT)
	DECLARE @tmpInputTransId_ReCalculate TABLE(TransId BIGINT, RequestID INT)
	
	DECLARE @tmpBalanceMember TABLE (CustId INT, Balance MONEY)
	DECLARE @tmpMatch_Eventdate TABLE (MatchId INT, Eventdate DATETIME)
	DECLARE @tmpCustCashOut TABLE (CustId INT)		
	DECLARE @tmpCustCashOut_VOID TABLE (CustId INT)
	DECLARE @tmpCustCashOut_Recalculate TABLE (CustId INT)
						
	CREATE TABLE #tblCashOutProcess (transid BIGINT, refno BIGINT, IsAvailable BIT DEFAULT 0)
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
	CREATE TABLE #tblMatchParlayProcess (matchId INT, RefNo BIGINT)
	CREATE TABLE #tmpTransId_VOID_RequestID (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,Action				VARCHAR(100)
		,RequestID			INT
		,isFinish			BIT 
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
		,winlostdate		DATETIME
	)
	
	CREATE TABLE #tmpTransId_Recalculate (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,balanceType		TINYINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,Action				VARCHAR(100)
		,isFinish			BIT
		,sporttype			SMALLINT
		,matchid			INT
		,oddsid				INT
		,winlostdate		DATETIME
	)
	
	DECLARE @tmpTransIDBatch TABLE (
		TransId				BIGINT
		,custid				INT
		,bettype			SMALLINT
		,KeyId				TINYINT DEFAULT(1)
		,Refno				BIGINT
		,balanceType		TINYINT
		,TicketType			TINYINT -- 1: Single, 3: Cash out, 4: Bettrade (not support), 5: Metric gaming
		,betid				BIGINT
		,betdaqid			BIGINT
		,extrainfo			VARCHAR(1000)
		,awinlost			MONEY
		,actual_stake		MONEY
		,isSubTransaction	BIT	DEFAULT(0)
		,refcode			BIGINT
		,Action				VARCHAR(100)
		,RequestID			INT
		,isFinish			BIT 
	)
	
	DECLARE @tblRequestList AS TABLE (QueueID INT, Matchid INT, RequestID INT)
	DECLARE @tblMatchid_abnormal AS TABLE (matchid INT)
	DECLARE @ProblemAccount_tmp AS TABLE (CustID INT)
	
	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	
	CREATE TABLE #Transid_mark_void (transid BIGINT,isFinish BIT )
	CREATE TABLE #Transid_mark_tmp (transid BIGINT, statuswinlost TINYINT)
	
	CREATE TABLE #tmpRefCodeSummary_VOID (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
		 ,RequestID	INT

	)
	
	CREATE TABLE #tmpRefCodeSummary_Recalculate (
		 RefCode	BIGINT
		 ,custid	INT
		 ,bettype	SMALLINT
		 ,transid	BIGINT
		 ,RequestID	INT

	)

	CREATE TABLE #balanceGameBefore (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)
	CREATE TABLE #balanceGameAfter (custid INT, winlostdate SMALLDATETIME, balance MONEY, winlost MONEY, gametypeid SMALLINT, groupid SMALLINT)

	CREATE TABLE #Lucky3Matches
	(
		MatchID				INT PRIMARY KEY,
		Has1stPrize			BIT,
		NumberOf1stPrize	INT DEFAULT(0),
		NumberOf2ndPrize	INT DEFAULT(0),
		NumberOf3rdPrize	INT DEFAULT(0)
	)
	
	SET @StartTime = GETDATE()
	SET @LogActionId = 90504
	SET @SB_Error = 0

	SET @session = CAST(NEWID() AS NVARCHAR(50))	
	SET @IssueTypeId = (SELECT IssueTypeId FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestID)

	SELECT  @LeagueId = m.leagueid, @HomeId = homeid, @AwayId = awayid, @KickOffTime = kickofftime, @IsTest = l.isTest, @LeagueGroupID = ISNULL(l.LeagueGroupID,0)
	FROM dbo.match m WITH (NOLOCK)
		INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
	WHERE matchid = @MatchId		
	
	--get list VIP Account
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
								FROM dbo.Dep_CustVIP WITH (NOLOCK)	
								'
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
	INSERT INTO @VIPAccount_tmp(CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

	IF @RequestID > 0
	BEGIN
		INSERT INTO #inputRequestTransId (TransId, RequestID, IssueTypeId, RequestType, DecidedBy, ActionId)
		SELECT  rds.transid, rd.RequestID, req.IssueTypeId, rd.RequestType, req.DecidedBy, req.ActionId
		FROM dbo.TicketVoiding_Request req WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK) ON rds.RequestId = req.RequestId AND rd.MatchId = rds.MatchId
		WHERE 1 = CASE WHEN req.IssueTypeId IN (11,15) AND rd.MatchId = @MatchId AND req.ActionId IN (1,4,6,7) -- Auto Void Winning, Auto Void All (Instant), Auto Void 5m & 10m before KOtime request only, not for take notes and waiting
							AND rd.RequestId = @RequestID THEN 1
						WHEN req.IssueTypeId = 13  AND req.ActionId = 4 -- Auto Void All (Instant) request only
							AND rd.RequestId  = @RequestID  THEN 1
						ELSE 0 END
	END
	ELSE
	BEGIN
		SET @IsActiveVoidWinning = (SELECT TOP (1) IsActive 
								FROM DBCUST.CUSTDB.dbo.ProblemAccountAction WITH (NOLOCK) 
								WHERE ActionID = 2)
								
		IF @IsActiveVoidWinning = 1
		BEGIN
			SELECT  @query = N''		
			SELECT	@query = @query + N'SELECT Custid 
										FROM dbo.ProblemAccount WITH (NOLOCK)	
										WHERE Actionid = 2 and SubIssueTypeId = 38'
			SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'

			INSERT INTO @ProblemAccount_tmp (CustID)
			EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query
			
			-- check and create request first for auto mark ticket or marked manually
			IF @@ROWCOUNT > 0 AND @sporttype NOT IN (50)
			BEGIN
				INSERT INTO #Transid_mark_tmp (transid,statuswinlost)
				SELECT b.transid, b.statuswinlost
				FROM dbo.MarkedTransaction mt WITH (NOLOCK) 
					INNER LOOP JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = mt.TransId AND b.statusID = 0 
					CROSS APPLY (SELECT TOP (1) custid
								FROM @ProblemAccount_tmp pa
								WHERE pa.CustID = b.CustId ) pa_tmp
					OUTER APPLY (SELECT TOP 1 r.RequestId
								FROM dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK) 
									INNER JOIN dbo.TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rds.RequestId
								WHERE mt.MatchId = rds.MatchId AND r.IssueTypeId = 11 
									AND r.ActionId NOT IN (2,3) -- 2: Take Note, 3 Waiting 
									AND mt.TransId = rds.TransId
								) AS tmp
				WHERE mt.MatchId = @MatchId 
					AND tmp.RequestId IS NULL
					AND b.statuswinlost IN (0,1,2,3,4)
					AND 1 = CASE WHEN @Sporttype = 50 AND b.bettype IN (501) THEN 0 ELSE 1 END -- Exclude bettype 501 of Cricket
					
				-- only create request for void ticket, base on this temp table to create request for void ticket	
				INSERT INTO #Transid_mark_void (transid)
				SELECT transid
				FROM #Transid_mark_tmp
				WHERE statuswinlost IN (1,2)
			END
		END
		
		IF EXISTS (SELECT TOP (1) 1 FROM #Transid_mark_void)
		BEGIN
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
				
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId
				INTO @tmpTransIDBatch(TransId)
				FROM #Transid_mark_void t 
				WHERE isFinish IS NULL
				
				IF @@ROWCOUNT = 0 BREAK
				
				
				-- Create new request here
				INSERT INTO dbo.TicketVoiding_Request (Sporttype, ActionId, Provider, Source, DecidedBy, MistakenBy, Remark, UserId, LastModifiedBy, IsTest, IssueTypeId)
				SELECT @Sporttype, 1, NULL, NULL, 'Abnormal Data Investigate', NULL, NULL, @UserId, @UserId, @IsTest, 11

				SET @RequestId = SCOPE_IDENTITY()
			
				INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, KickOffTime,RequestType, SubIssueTypeId)
				SELECT @RequestId, @MatchId, @LeagueId, @HomeId, @AwayId, @KickOffTime, 2 , 38
				
				SET @RequestDetailId = SCOPE_IDENTITY()

				INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId,IssueTypeId,SubIssueTypeId,TransId,MatchId, RequestDetailId)
				SELECT @RequestID, 11, 38, TransId, @MatchId, @RequestDetailId
				FROM @tmpTransIDBatch
				
			END
		END	
	
		-- get all transid from all requests
		INSERT INTO #inputRequestTransId (RequestID,TransId, IssueTypeId, RequestType, ActionId)
		SELECT  req.RequestID, rds.transid, req.IssueTypeId, rd.RequestType, req.ActionId
		FROM dbo.TicketVoiding_Request req WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rds WITH (NOLOCK) ON rds.RequestId = req.RequestId
		WHERE req.IssueTypeId IN (11,15) AND rd.MatchId = @MatchId 
			AND req.ActionId = 1 -- Auto Void Winning ONLY, Auto Void All (Instant) will cover at the time process for request in queue
		
	END
	--Check duplicate transid belong multi request--
	IF EXISTS (SELECT TOP (1) 1 FROM #inputRequestTransId GROUP BY TransId HAVING COUNT(1) > 1)
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = 'Some tickets of this match are being duplicated in multi requests!'	
		RETURN
	END
	
	-- get transid to VOID
	INSERT INTO @tmpInputTransId_VOID (TransId, RequestID, IssueTypeId, DecidedBy, Winlostdate, StatusId)
	SELECT	tl.translogid, t.RequestID, t.IssueTypeId, t.DecidedBy, tl.winlostdate, tl.statusID
	FROM	#inputRequestTransId t 
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON t.TransId = tl.translogid
	WHERE	tl.statusID <> 102

	SET @Void_cnt = @@ROWCOUNT

	IF @Void_cnt <> 0
		SET @isExistMG = 1


	INSERT INTO @tmpInputTransId_VOID (TransId, RequestID, IssueTypeId, DecidedBy, Winlostdate, StatusId)
	SELECT t.TransId, t.RequestID, t.IssueTypeId, t.DecidedBy, b.winlostdate, statusID
	FROM #inputRequestTransId t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid
		OUTER APPLY (SELECT TOP (1) ac.CustID 
					 FROM @VIPAccount_tmp ac 
					 WHERE  ac.CustID = b.custid
					 ) AS vip
	WHERE 1 = CASE
				WHEN t.IssueTypeId = 13 AND t.RequestType = 1 THEN 1 -- Void Instant for Abnormal Account, void account VIP
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND t.IssueTypeId IN (11,15) AND t.RequestType = 3 AND t.ActionId = 1 AND b.statuswinlost IN (1,2) THEN 1 --Auto void winning request, void VIP + normal member
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND t.IssueTypeId IN (11,15) AND t.RequestType = 3 AND t.ActionId IN (4,6,7) THEN 1 --Auto void Instant & 5m &10m, void VIP + normal member
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND t.IssueTypeId <> 13 AND t.RequestType = 1 AND vip.CustID IS NULL THEN 1 -- Void Instant Request
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND t.RequestType <> 1 AND b.statuswinlost IN (1,2) AND vip.CustID IS NULL THEN 1 -- Auto void winning request
			ELSE 0 END
		
	SET @Void_cnt = @Void_cnt + @@ROWCOUNT
	
	-- get transid to unmark and resettle
	INSERT INTO @tmpInputTransId_ReCalculate (TransId)
	SELECT DISTINCT t.TransId
	FROM (SELECT transid, IssueTypeId, RequestType, ActionId
		FROM #inputRequestTransId 
		UNION  
		SELECT transid, 0 AS IssueTypeId, 0 AS RequestType, 0 AS ActionId
		FROM #Transid_mark_tmp
		WHERE statuswinlost IN (0,3,4)
		
		) AS t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid
		OUTER APPLY  (SELECT TOP (1) ac.CustID 
					 FROM @VIPAccount_tmp ac 
					 WHERE  ac.CustID = b.custid
					 ) AS vip
	WHERE 1 = CASE 
				WHEN t.IssueTypeId = 13 AND t.RequestType = 1 THEN 0
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND t.IssueTypeId IN (11,15) AND t.RequestType = 3 AND t.ActionId = 1 AND b.statuswinlost IN (1,2) THEN 0
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND t.IssueTypeId IN (11,15) AND t.RequestType = 3 AND t.ActionId IN (4,6,7) THEN 0 
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND b.statuswinlost IN (0,3,4) THEN 1
				WHEN b.matchid = @MatchId AND b.statusID = 0 AND vip.CustID IS NOT NULL AND b.statuswinlost IN (1,2) AND t.RequestType <> 3 THEN 1
			  ELSE 0 END
				
	SET @Recalculate_cnt = @@ROWCOUNT
	
	IF @Void_cnt = 0 AND @Recalculate_cnt = 0
	BEGIN
		SELECT	@ErrCode = 0
				,@ErrMsg = 'No ticket found.'	
		RETURN
	END
	-------------DATA PREPARATION ------------
	INSERT INTO #tmpTransId_VOID_RequestID(custid, bettype, KeyId, Refno, actual_stake, TicketType, matchid, RequestID, winlostdate)
	SELECT	tl.custid, tl.gameID, 3, tl.translogid, tl.actual_stake, 5 -- Metric gaming
		, tl.eventID, t.RequestID, t.Winlostdate
	FROM	@tmpInputTransId_VOID t 
		INNER JOIN dbo.translog tl WITH(NOLOCK)
			ON t.TransId = tl.translogid
	WHERE	tl.statusID <> 102				

	INSERT INTO #tmpTransId_VOID_RequestID(TransId, custid, bettype, KeyId, TicketType, betdaqid, extrainfo, refcode, betid,RequestID, matchid, oddsid, winlostdate, Refno)
	SELECT	b.transid, b.custid, b.bettype
			,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3
				WHEN b.betdaqid = 1 AND b.bettype NOT IN (911, 912, 913) THEN 3
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid
			, t.RequestID
			,b.matchid, b.oddsid, t.Winlostdate, b.refno
	FROM @tmpInputTransId_VOID AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
		OUTER APPLY (
					SELECT GroupId
					FROM f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	INSERT INTO #tmpTransId_Recalculate(TransId, custid, bettype, KeyId, balanceType, TicketType, betdaqid, extrainfo, refcode, betid, matchid, oddsid, winlostdate, Refno)
	SELECT	b.transid, b.custid, b.bettype
			,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
			,1 AS balanceType
			,CASE 
				WHEN b.betdaqid = 0 AND CHARINDEX('p25', b.ExtraInfo) > 0 THEN 3
				WHEN b.betdaqid = 1 AND b.bettype NOT IN (911, 912, 913) THEN 3
				ELSE 1 END AS TicketType
			,b.betdaqid, b.ExtraInfo, b.RefCode, b.betid, b.matchid, b.oddsid, b.winlostdate, b.refno
	FROM @tmpInputTransId_ReCalculate AS t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid
		OUTER APPLY (
					SELECT GroupId
					FROM f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	
	-- UPDATE eventtype = 1
	IF(EXISTS (SELECT 1 FROM #tmpTransId_VOID_RequestID WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE	b
		SET sporttype 	= m.sporttype
		FROM	#tmpTransId_VOID_RequestID b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		WHERE bettype NOT IN (9, 29, 2799)
			
	END

	IF(EXISTS (SELECT 1 FROM #tmpTransId_Recalculate WHERE bettype NOT IN (9, 29, 2799)))
	BEGIN
		UPDATE	b
		SET sporttype 	= m.sporttype
		FROM	#tmpTransId_Recalculate b
			INNER JOIN dbo.match m WITH(NOLOCK)
				ON	b.matchid = m.matchid
		WHERE bettype NOT IN (9, 29, 2799)
			
	END
	
	-- -- UPDATE eventtype = 2 [Outright ticket]
	IF(EXISTS (SELECT 1 FROM #tmpTransId_VOID_RequestID WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET sporttype	= l.sporttype
		FROM	#tmpTransId_VOID_RequestID b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
		WHERE bettype IN (10)
	END

	IF(EXISTS (SELECT 1 FROM #tmpTransId_Recalculate WHERE bettype IN (10)))
	BEGIN
		UPDATE b
		SET sporttype	= l.sporttype
		FROM	#tmpTransId_Recalculate b
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	b.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
		WHERE bettype IN (10)
	END
	
	-- -- UPDATE eventtype = 3 [VS range bettypes]
	IF(EXISTS (SELECT 1 FROM #tmpTransId_VOID_RequestID WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET sporttype 	= r.sporttype	
		FROM	#tmpTransId_VOID_RequestID b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END

	IF(EXISTS (SELECT 1 FROM #tmpTransId_Recalculate WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE b
		SET sporttype 	= r.sporttype		
		FROM	#tmpTransId_Recalculate b
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON b.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE b.bettype IN (1231,1232,1233,1237,1238)
	END

	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #tmpTransId_VOID_RequestID b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END
	BEGIN
		UPDATE b
		SET sporttype = sb.SportType
		FROM #tmpTransId_Recalculate b
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON b.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- remove un-supported sports & bettype
	DELETE bd
	FROM #tmpTransId_VOID_RequestID bd
	WHERE bettype NOT IN (9, 29, 2799)
		AND (
			sporttype IS NULL
			OR bettype = 500 /*charge comm*/
		) 
	
	-- check and not allow attempt to settlement same game while it's still not finish
	SELECT @isExistMatch 				= MAX(CASE WHEN Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@isExistMG 				= MAX (CASE WHEN Bettype BETWEEN 801 AND 806 THEN 1 ELSE 0 END)
			,@isExistFM 				= MAX (CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@isExistOutright 			= MAX (CASE WHEN Bettype = 10 THEN 1 ELSE 0 END)
			,@isExistParlay 			= MAX (CASE WHEN Bettype IN (9, 29) THEN 1 ELSE 0 END)
			,@IsExistParlayVSBetradar	= MAX (CASE WHEN Bettype IN (2799) THEN 1 ELSE 0 END)
			,@IsExistVSBetradar			= MAX (CASE WHEN sporttype BETWEEN 190 AND 199 THEN 1 ELSE 0 END)
			,@isExistNG 				= MAX (CASE WHEN Bettype BETWEEN 81 AND 120 OR Bettype BETWEEN 8101 AND 8120 THEN 1 ELSE 0 END)
			,@isExistBT 				= MAX (CASE WHEN betdaqid = 0 AND extrainfo is null THEN 1 ELSE 0 END)
			,@isExistCashOut			= MAX (CASE WHEN betdaqid = 0 AND charindex ('p25',extrainfo)> 0 THEN 1 ELSE 0 END)
			,@isExistCricket 			= MAX (CASE WHEN Bettype = 501 THEN 1 ELSE 0 END)
			,@isExistLC					= MAX (CASE WHEN Bettype BETWEEN 1101 AND 1199 THEN 1 ELSE 0 END)
			,@isExistVS					= MAX (CASE WHEN Bettype BETWEEN 1201 AND 1299 THEN 1 ELSE 0 END)
			,@isExistBB					= MAX (CASE WHEN Bettype IN (38) THEN 1 ELSE 0 END)
			,@isExistLucky3		= MAX (CASE WHEN Bettype BETWEEN 1600 AND 1610 THEN 1 ELSE 0 END)
			,@isExistFM2				= MAX (CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
	FROM	
		(
			SELECT v.bettype, v.betdaqid, v.sporttype, v.extrainfo
			FROM #tmpTransId_VOID_RequestID v
			UNION ALL
			SELECT r.bettype, r.betdaqid, r.sporttype, r.extrainfo
			FROM #tmpTransId_Recalculate r
		)b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f

	
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT DISTINCT matchid
		, CASE 
			WHEN Bettype NOT IN (9, 29, 2799, 10, 38) 
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
			ELSE 0
		END AS KeyID
	FROM #tmpTransId_VOID_RequestID b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	UNION ALL
	SELECT DISTINCT @MatchId AS matchid
		, CASE 
			WHEN Bettype NOT IN (9, 29, 2799, 10, 38) 
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
			ELSE 0
		END AS KeyID
	FROM #tmpTransId_Recalculate b
		OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.Bettype
			)f
	IF @IssueTypeId = 13 -- Abnormal account
	BEGIN
		INSERT INTO #tblMatchParlayProcess ( matchId, RefNo)
		SELECT b.matchid, b.Refno
		FROM 
			(
				SELECT v.matchid, v.Refno
				FROM #tmpTransId_VOID_RequestID v
				WHERE v.matchid IN (9,29) --NOT 2799: Virtual Sport
				UNION ALL
				SELECT r.matchid, r.Refno
				FROM #tmpTransId_Recalculate r
				WHERE r.matchid IN (9,29) --NOT 2799: Virtual Sport
			)b
	
		EXEC dbo.NAP_Set_GlobalSettingSel 
			 @LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

		SET @totalMainParlay = @@ROWCOUNT
	END

	-- Apply new way to lock parlay tickets	
	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold 
	BEGIN
		IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
			OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
		BEGIN
			-- checking single proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@isExistOutright 			= @isExistOutright
				, @isExistMG				= @isExistMG
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @isExistMatch
				, @isExistNG				= @isExistNG
				, @isExistVS				= @isExistVS
				, @isExistBB				= @isExistBB
				, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				, @isExistFM2				= @isExistFM2
				, @spName					= @spName
				, @avaiableProcess 			= @avaiableProcess OUTPUT
				, @ErrCode					= @ErrCode OUTPUT
				, @ErrMsg					= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN
				SET @ErrCode = 9999
				
				RETURN
			END
		END

		IF @totalMainParlay > 0 
		BEGIN
			-- checking Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				 @IsLockingByRefno	= 1
				,@spName			= @spName
				,@Session			= @Session
				,@avaiableProcess 	= @avaiableProcess OUTPUT
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT

			IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
			BEGIN
				SET @ErrCode = 9999

				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
						@isExistOutright 			= @isExistOutright
						, @isExistMG				= @isExistMG
						, @isExistFM				= @isExistFM
						, @isExistMatch				= @isExistMatch
						, @isExistNG				= @isExistNG
						, @isExistVS				= @isExistVS
						, @isExistBB				= @isExistBB
						, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
						, @isExistFM2				= @isExistFM2
						, @IsReleased				= 1	
				RETURN
			END
		END
				
	END
	ELSE IF @totalMainParlay > @ThreadHold
	BEGIN
		--check settlement process
		EXEC dbo.NAP_Admin_CheckingProcess
			@isExistParlay 				= @isExistParlay
			, @isExistOutright 			= @isExistOutright
			, @isExistMG				= @isExistMG
			, @isExistFM				= @isExistFM
			, @isExistMatch				= @isExistMatch
			, @isExistNG				= @isExistNG
			, @isExistVS				= @isExistVS
			, @isExistBB				= @isExistBB
			, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
			, @isExistFM2				= @isExistFM2
			, @spName					= @spName
			, @avaiableProcess 			= @avaiableProcess OUTPUT
			, @ErrCode					= @ErrCode OUTPUT
			, @ErrMsg					= @ErrMsg OUTPUT

		IF(@ErrCode <> 0 OR @avaiableProcess = 0) 
		BEGIN
			SET @ErrCode = 9999
				
			RETURN
		END
	END	

	IF EXISTS (SELECT TOP 1 1 
				FROM #tmpTransId_VOID_RequestID t	
				WHERE	t.TicketType = 3)
	BEGIN			
		-- checking cash-out process
		INSERT INTO #tblCashOutProcess(transid)
		SELECT	t.transid
		FROM	#tmpTransId_VOID_RequestID t	
		WHERE	t.TicketType = 3 

		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
			,@Action = 'Void'
			,@IsReleased = 0

		DELETE	t
		FROM	#tmpTransId_VOID_RequestID t
			 INNER JOIN #tblCashOutProcess co
					 ON t.transid = co.transid					
						AND co.IsAvailable = 0
		DELETE	t
		FROM	@tmpInputTransId_VOID t
			 INNER JOIN #tblCashOutProcess co
					 ON t.transid = co.transid					
						AND co.IsAvailable = 0
	END
	
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID))  
	BEGIN
		-------> releasing cash-out process
		EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
			  , @Action = 'Void'
			  , @IsReleased = 1 
		
	END
	
	IF (NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID) AND @Recalculate_cnt = 0)
	BEGIN
		IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
		BEGIN
			IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
				 OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
			BEGIN
				------ releasing single process
				EXEC dbo.NAP_Admin_CheckingProcess
						@isExistOutright 			= @isExistOutright
						, @isExistMG				= @isExistMG
						, @isExistFM				= @isExistFM
						, @isExistMatch				= @isExistMatch
						, @isExistNG				= @isExistNG
						, @isExistVS				= @isExistVS
						, @isExistBB				= @isExistBB
						, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
						, @isExistFM2				= @isExistFM2
						, @IsReleased				= 1	
			END

			IF @totalMainParlay	> 0 
			BEGIN
				------ releasing Refno parlay proccess
				EXEC dbo.NAP_Admin_CheckingProcess
					@IsLockingByRefno = 1
				   ,@Session	= @Session
				   ,@IsReleased = 1				
			END
		END
		ELSE IF @totalMainParlay > @ThreadHold
		BEGIN
			------ releasing SD process
			EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 				= @isExistParlay
					, @isExistOutright 			= @isExistOutright
					, @isExistMG				= @isExistMG
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @IsReleased				= 1
		END
		
		SELECT	@ErrCode = 0
				,@ErrMsg = 'No ticket found.'				
		RETURN
	END	
	
	-- Capture request and its void tickets to insert voidingHistory
	INSERT INTO @AutoVoid_ValidRequest (RequestID, IssueTypeId, Transids, MinWinlostdate, MaxWinlostdate)			
	SELECT DISTINCT r.RequestID, r.IssueTypeId, STUFF(tmp.Transids,1,1,'') AS Transids, r.MinWinlostdate, r.MaxWinlostdate
	FROM(
		  SELECT DISTINCT RequestID, IssueTypeId, MIN (Winlostdate) AS MinWinlostdate, MAX( Winlostdate) AS MaxWinlostdate
		  FROM @tmpInputTransId_VOID
		  GROUP BY RequestID, IssueTypeId 
		) AS r
		CROSS APPLY (SELECT ',' + CAST(v.transid AS VARCHAR(50))
					FROM @tmpInputTransId_VOID v
					WHERE v.RequestID = r.RequestID
					FOR XML PATH ('')
					) AS tmp (Transids)
	
	-- Checking Cashout for VOID
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID t WHERE t.TicketType = 3)
	BEGIN
		-- get 911
		INSERT INTO #tmpTransId_VOID_RequestID (TransId, custid, Refno, bettype, TicketType, isSubTransaction,RequestID, sporttype)
		SELECT	sub.transid, sub.custid, sub.refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, main.RequestID, main.sporttype
		FROM	#tmpTransId_VOID_RequestID main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = @MatchId
					AND sub.custid = main.custid
					AND sub.bettype = 911
		WHERE	main.TicketType = 3
				AND sub.statusID NOT IN (101, 102)

		-- cashout bet ticket, 912, 913
		INSERT INTO #tmpTransId_VOID_RequestID(TransId, custid, Refno, bettype, TicketType, isSubTransaction, RequestID, sporttype)
		SELECT	sub.TransId, sub.custid, sub.Refno, sub.bettype, 3 AS TicketType, 1 AS isSubTransaction, sub911.RequestID, sub911.sporttype
		FROM	#tmpTransId_VOID_RequestID sub911
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = sub911.TransId
					AND sub.matchid = @MatchId
		WHERE	sub.statusID NOT IN (101, 102)
				AND sub911.bettype = 911
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID r WHERE r.TransId = sub.transid)	

		INSERT INTO @tmpCustCashOut_VOID(CustId)
		SELECT	t.custid
		FROM	#tmpTransId_VOID_RequestID t
		WHERE	t.TicketType = 3
				AND t.bettype = 912
		GROUP BY t.custid
		
	END
	-- Checking CASHOUT for resettle, used to recal 914 for affect customers
	DECLARE @tmpCustCashOut_Recalculate_tmp AS TABLE(transid BIGINT, custid INT, refno BIGINT, bettype SMALLINT, sporttype SMALLINT)
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate t WHERE t.TicketType = 3)
	BEGIN
		-- get 911
		INSERT INTO @tmpCustCashOut_Recalculate_tmp (transid, custid, refno, bettype, sporttype)
		SELECT	sub.transid, sub.custid, sub.refno, sub.bettype, main.sporttype
		FROM	#tmpTransId_Recalculate main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = main.TransId
					AND sub.matchid = @MatchId
					AND sub.custid = main.custid
					AND sub.bettype = 911
		WHERE	main.TicketType = 3
				AND sub.statusID NOT IN (101, 102)
		-- cashout bet ticket, 912, 913
		INSERT INTO @tmpCustCashOut_Recalculate_tmp (transid, custid, refno, bettype, sporttype)
		SELECT	sub.TransId, sub.custid, sub.Refno, sub.bettype, sub911.sporttype
		FROM	@tmpCustCashOut_Recalculate_tmp sub911
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	sub.refno = sub911.TransId
					AND sub.matchid = @MatchId
		WHERE	sub.statusID NOT IN (101, 102)
				AND sub911.bettype = 911

		INSERT INTO @tmpCustCashOut_Recalculate(CustId)
		SELECT	t.custid
		FROM	@tmpCustCashOut_Recalculate_tmp t
		WHERE	t.bettype = 912
		GROUP BY t.custid
		
		INSERT INTO #tmpTransId_Recalculate (TransId, custid, bettype, KeyId, balanceType, TicketType, betdaqid, extrainfo, refcode, betid, sporttype)
		SELECT	DISTINCT cob.transid, cob.custid, cob.bettype
			,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
			,1 AS balanceType
			,3 AS TicketType
			,cob.betdaqid, cob.ExtraInfo, cob.RefCode, cob.betid, b.sporttype
		FROM @tmpCustCashOut_Recalculate_tmp b
			INNER JOIN dbo.bettrans cob WITH(NOLOCK) 
				ON cob.matchid = @MatchId
				AND cob.custid = b.custid
				AND cob.refno = b.refno 
				AND cob.bettype NOT BETWEEN 912 AND 914 --normal bettype tickets
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = b.bettype
			)f
		WHERE b.bettype = 912
			AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate r WHERE r.TransId = cob.transid)	
		
	END
	
	-- Cashout for all void and resettle
	INSERT INTO @tmpCustCashOut (CustId)
	SELECT custid
	FROM @tmpCustCashOut_VOID
	UNION 
	SELECT custid
	FROM @tmpCustCashOut_Recalculate
	
	-- Insert more bonus or cash ticket in case only one ticket appears in #tmpTransId	
	INSERT INTO #tmpRefCodeSummary_VOID (RefCode, custid, bettype, transid,requestID)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid, requestID
	FROM	#tmpTransId_VOID_RequestID t
	WHERE	t.refcode IS NOT NULL 
	GROUP BY t.refcode, t.custid, t.bettype, RequestID
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId_VOID_RequestID (TransId, custid, bettype, KeyId, TicketType, refcode, RequestID, betid)
		SELECT b.TransId, b.custid, b.bettype
		,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
		, 1, b.refcode, r.RequestID, b.betid
		FROM #tmpRefCodeSummary_VOID r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = r.bettype
			)f
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID WHERE b.transid = TransId)
	END
	INSERT INTO #tmpRefCodeSummary_Recalculate(RefCode, custid, bettype, transid)
	SELECT	RefCode, custid, bettype, MAX(transid) as transid
	FROM	#tmpTransId_Recalculate t
	WHERE	t.refcode IS NOT NULL 
	GROUP BY t.refcode, t.custid, t.bettype
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tmpTransId_Recalculate(TransId, custid, bettype, KeyId, balanceType, TicketType, refcode)
		SELECT b.TransId, b.custid, b.bettype
		,CASE 
				WHEN f.GroupId IS NULL THEN 1
				WHEN f.GroupID = 2 THEN 7 
			END AS KeyId
		, 1, 1, b.refcode
		FROM #tmpRefCodeSummary_Recalculate r
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
				ON	b.RefCode = r.RefCode
					AND b.transid <> r.transid
					AND b.matchid = @MatchId
					AND b.custid = r.custid
					AND b.bettype = r.bettype
			OUTER APPLY (
					SELECT GroupId
					FROM dbo.f_TVS_CheckingProcessGroupBettypes()
					WHERE Bettype = r.bettype
			)f
		WHERE	b.statusID NOT IN (101,102 ) -- reject, void
				AND NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransId_Recalculate WHERE b.transid = TransId)
				
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID t WHERE t.TicketType = 5)
	BEGIN
		INSERT INTO [bodb02].[dbo].[bettrans]  (
				[custid]  
				,[transdate]  
				,[oddsid]  
				,[hdp1]  
				,[hdp2]  
				,[odds]  
				,[stake]  
				,[status]  
				,[winlost]  
				,[awinlost]  
				,[mwinlost]  
				,[playercomm]  
				,[comm]  
				,[acomm]  
				,[apositiontaking]  
				,[mpositiontaking]  
				,[tpositiontaking]  
				,[playerdiscount]  
				,[discount]  
				,[adiscount]  
				,[livehomescore]  
				,[liveawayscore]  
				,[liveindicator]  
				,[betteam]  
				,[creator]  
				,[refno]  
				,[comstatus]  
				,[winlostdate]  
				,[betfrom]  
				,[betcheck]  
				,[checktime]  
				,[oddsspread]  
				,[actualrate]  
				,[matchid]  
				,[recommend]  
				,[mrecommend]  
				,[ruben]  
				,[betid]  
				,[statuswinlost]  
				,[modds]  
				,[bettype]  
				,[betdaqid]  
				,[actual_stake]  
				,[currency]  
				,[ip]  
				,[transdesc]  
				,[sdiscount]  
				,[scomm]  
				,[spositiontaking]  
				,[swinlost]  
				,[srecommend]  
				,[Username]  
				,[CurrencyName]  
				,[virtualrate]  
				,[oddstype]  
				,[statusID]  
				,[currency2]  
				,[balance]  
				,[SecAcceptFlag]  
				,[transid2]  
				,[RecommDate]
				,[epositiontaking]
		)  
		SELECT	tl.[custid]  
				,tl.[transdate]  
				,0 [oddsid]  
				,0 [hdp1]  
				,0 [hdp2]  
				,tl.[odds]  
				,tl.[stake]  
				,tl.[status]  
				,0 [winlost]  
				,0 [awinlost]  
				,0 [mwinlost]  
				,0 [playercomm]  
				,0 [comm]  
				,0 [acomm]  
				,tl.[apositiontaking]  
				,tl.[mpositiontaking]  
				,tl.[tpositiontaking]  
				,tl.[playerdiscount]  
				,tl.[discount]  
				,tl.[adiscount]  
				,0 [livehomescore]  
				,0 [liveawayscore]  
				,tl.[liveindicator]  
				,SUBSTRING(tl.[transdesc],11,CHARINDEX(';BettypeTime',tl.[transdesc],0) - 11) [betteam]  
				,tl.[creator]  
				,tl.translogid [refno]  
				,tl.custom2 [comstatus]  
				,tl.[winlostdate]  
				,tl.[betfrom]  
				,tl.transdate [betcheck]  
				,NULL [checktime]  
				,0 [oddsspread]  
				,tl.[actualrate]  
				,tl.EventID  
				,tl.[recommend]  
				,tl.[mrecommend]  
				--,1 [ruben]  
				,0 [ruben] --#94603
				,CASE WHEN ISNULL(tl.custom3,'') = '' THEN NULL ELSE CAST(tl.custom3 AS BIGINT) END [betid]  
				,NULL [statuswinlost]  
				,0 [modds]  
				,tl.GameID [bettype]  
				,NULL [betdaqid]  
				--,b.[actual_stake] --#94603 
				,0 [actual_stake]
				,tl.[currency]  
				,tl.[ip]  
				,tl.[transdesc]  
				,tl.[sdiscount]  
				,0 [scomm]  
				,tl.[spositiontaking]  
				,0 [swinlost]  
				,tl.[srecommend]  
				,tl.[Username]  
				,tl.[CurrencyName]  
				,tl.[virtualrate]  
				,tl.custom1 [oddstype]  
				,tl.[statusID]  
				,NULL [currency2]  
				,tl.[balance]  
				,0 [SecAcceptFlag]  
				,0 [transid2]  
				,NULL [RecommDate]
				,tl.[epositiontaking] 				
			FROM #tmpTransId_VOID_RequestID t
				INNER JOIN dbo.translog tl WITH(NOLOCK)  
					ON tl.translogid = t.Refno
			WHERE NOT EXISTS (
					SELECT TOP 1 1 
					FROM dbo.bettrans b WITH(NOLOCK) 
					WHERE b.custid = tl.custid 
						AND b.refno = tl.translogid 
						AND b.matchid = tl.eventID
				)

		UPDATE  t
			SET TransId = b.transid
				,betid = ISNULL(b.BetID, rs.ResultID)
		FROM	#tmpTransId_VOID_RequestID t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.Refno = b.refno
					AND b.matchid = t.matchid
					AND b.bettype = t.bettype
					AND b.custid = t.custid
			OUTER APPLY (
				SELECT	rs.ResultID
				FROM	DBPRO.bodb02.dbo.ResultDetail3rd rs WITH(NOLOCK)
				WHERE	(
							(ISNULL(rs.Custom1,'') <> '' AND CHARINDEX('BettypeTime='+ rs.Custom1, b.transdesc,0) <> 0)
							OR b.bettype = 806
						)
						AND rs.GameID = b.bettype	
						AND rs.VendorID = 5		
						AND rs.MatchID = b.matchid	
			) rs
		WHERE	t.TicketType = 5

	END
	
	----------------- END OF PREPARATION -----------------------------------	
	-----------STARTING FOR VOID AND RE-Calculation-------------------------
	---------- Starting for Voiding Process ------------------------------------

	--Get data before update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
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
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END AS groupId
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId_VOID_RequestID tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120
			OR b.bettype BETWEEN 1201 AND 1299
			OR b.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE 
				WHEN b.bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN b.bettype BETWEEN 81 AND 120 OR b.bettype BETWEEN 8101 AND 8120THEN 81
				WHEN b.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END
	
	--capture balance before voiding & recal
	INSERT INTO @BeforeUpd(
		matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost 
					- CASE 
						WHEN t.TicketType = 5 THEN t.actual_stake -- get actual_stake from translog
						ELSE b.actual_stake 
					END 
					+ b.playercomm AS balance
		FROM #tmpTransId_VOID_RequestID t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
				
		UNION ALL
		
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost 
					- CASE 
						WHEN t.TicketType = 5 THEN t.actual_stake -- get actual_stake from translog
						ELSE b.actual_stake 
					END 
					+ b.playercomm AS balance
		FROM #tmpTransId_Recalculate  t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
				
		UNION ALL
		
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914
		
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType
	

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WITH (NOLOCK) WHERE RequestID = @RequestID)
	BEGIN
		SET @VoidDataXML = ( SELECT DISTINCT 
									'starixIT' AS "@CreatorName"
									,a.DecidedBy AS "@DecidedBy"
									,MIN(CONVERT(VARCHAR, a.Winlostdate, 101)) AS "@VoidFromDate"
									,MAX(CONVERT(VARCHAR, a.Winlostdate, 101)) AS "@VoidToDate"
									,MAX (CASE WHEN a.statusID IN (111, 112, 113) THEN 1 ELSE 0 END) AS "@IsHasSettledTicket"
							FROM @tmpInputTransId_VOID a
							WHERE a.IssueTypeId = 13
							GROUP BY a.DecidedBy
							FOR XML PATH('VoidData')
							)
		
		-- Insert Voiding History first
		INSERT INTO dbo.TicketVoiding_VoidingHistory (RequestId, UserId, StatusId, TransIds, VoidData, MinWinlostdate, MaxWinlostdate)
		OUTPUT INSERTED.RequestID
				,INSERTED.VoidingHistoryId
		INTO @VoidingHistory_tmp (RequestID,VoidingHistoryId)	
		SELECT  RequestID
				,@UserId
				, 1
				,CASE WHEN IssueTypeId IN (11,15) THEN TransIds ELSE NULL END
				,@VoidDataXML
				,CASE WHEN IssueTypeId = 13 THEN MinWinlostdate ELSE NULL END
				,CASE WHEN IssueTypeId = 13 THEN MaxWinlostdate ELSE NULL END
		FROM @AutoVoid_ValidRequest

		UPDATE v SET v.IssueTypeId = r.IssueTypeId
		FROM @VoidingHistory_tmp v
			INNER JOIN @AutoVoid_ValidRequest r ON r.RequestID = v.RequestID
	END

	SELECT @VoidingHistoryIds = STUFF((SELECT ',' + CAST(VoidingHistoryId AS VARCHAR(50)) FROM @VoidingHistory_tmp FOR XML PATH('')),1,1,'')

	-- Insert for WEB Auto Service PROCESS
	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)
						INNER JOIN @VoidingHistory_tmp t ON t.RequestID = s.RequestID AND t.VoidingHistoryId = s.VoidingHistory)
	BEGIN
		DECLARE @sessionID INT = 0
		SET @sessionID = ISNULL((SELECT MAX(sessionID) FROM dbo.Ticketvoiding_VoidBetAutomation_Service WITH (NOLOCK)),0) + 1

		INSERT INTO Ticketvoiding_VoidBetAutomation_Service (RequestID,VoidingHistory,statusID,matchID,SessionID,IsAutoVoid)
		SELECT vh.RequestID, vh.VoidingHistoryId,1,CASE WHEN vh.IssueTypeId <> 13 THEN @MatchId ELSE NULL END,@sessionID,1
		FROM @VoidingHistory_tmp vh
	END
	
	/*Modify the way to get move bet date*/
	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @Movebetdate OUTPUT
		
	INSERT INTO @tmpMatch_Eventdate (MatchId, Eventdate)
	SELECT DISTINCT t.MatchId, t.winlostdate
	FROM (
			SELECT t.matchid, t.winlostdate
			FROM #tmpTransId_VOID_RequestID t
			UNION ALL
			SELECT r.matchid, r.winlostdate
			FROM #tmpTransId_Recalculate r
		 )t
	
	SELECT @MatchId_cnt = COUNT(MatchId)
	FROM @tmpMatch_Eventdate t

	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatch_Eventdate WHERE Eventdate <= @Movebetdate)
	BEGIN
		DECLARE @tblMatchProcess_1 TABLE (matchid INT, KeyID TINYINT)
		DECLARE @tblCashOutProcess_1 TABLE (transid BIGINT)

		DELETE 
		FROM #tblMatchProcess
		OUTPUT	DELETED.matchid, DELETED.KeyID
		INTO  @tblMatchProcess_1 (matchid, KeyID)
		WHERE matchid NOT IN (SELECT matchid FROM @tmpMatch_Eventdate WHERE Eventdate <= @Movebetdate)

		------ releasing process
		EXEC dbo.NAP_Admin_CheckingProcess
				@isExistParlay 				= @isExistParlay
				, @isExistOutright 			= @isExistOutright
				, @isExistMG				= @isExistMG
				, @isExistFM				= @isExistFM
				, @isExistMatch				= @isExistMatch
				, @isExistNG				= @isExistNG
				, @isExistVS				= @isExistVS
				, @isExistBB				= @isExistBB
				, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				, @isExistFM2				= @isExistFM2
				, @IsReleased				= 1

		DELETE #tblMatchProcess
		INSERT INTO #tblMatchProcess(matchid, KeyID)
		SELECT matchid, KeyID FROM @tblMatchProcess_1

		IF EXISTS (SELECT TOP 1 1 
				FROM #tmpTransId_VOID_RequestID t	
				WHERE	t.TicketType = 3 AND winlostdate <= @Movebetdate)
		BEGIN		
		  	DELETE 
			FROM #tblCashOutProcess
			OUTPUT	DELETED.transid
			INTO  @tblCashOutProcess_1 (transid)
			WHERE transid NOT IN (SELECT transid FROM #tmpTransId_VOID_RequestID WHERE TicketType = 3 AND winlostdate <= @Movebetdate)

			------ releasing cash-out process
			EXEC dbo.NAP_Admin_CheckingCashOutProcess 
				@Mode = 'Original'
				,@Action = 'Void'
				,@IsReleased = 1
			
			DELETE #tblCashOutProcess
			INSERT INTO #tblCashOutProcess(transid)
			SELECT transid FROM @tblCashOutProcess_1
			
		END

		IF (@MatchId_cnt = 1) OR (NOT EXISTS (SELECT TOP 1 1 FROM @tblMatchProcess_1))
		BEGIN
			SELECT	@ErrCode = 99
					,@ErrMsg = 'Match is under Movebet process, could not void ticket.'

			RETURN
		END	
		ELSE
		BEGIN
			SELECT @MoveBetMatchIds = STUFF((SELECT DISTINCT  ',' + CAST( m.matchid AS VARCHAR(20))
							FROM @tmpMatch_Eventdate m
							WHERE eventdate <= @Movebetdate
							FOR XML PATH ('')
						),1,1,'')

			DELETE t
			FROM #tmpTransId_VOID_RequestID t
				INNER JOIN @tmpMatch_Eventdate m 
			ON t.matchid = m.matchid  AND t.winlostdate <= @Movebetdate
				
			DELETE r
			FROM #tmpTransId_Recalculate r
				INNER JOIN @tmpMatch_Eventdate m 
			ON r.matchid = m.matchid  AND r.winlostdate <= @Movebetdate	 	
					 	 
		END
	END

	BEGIN TRY
			  
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT DELETED.TransId,DELETED.custid, DELETED.Refno, DELETED.bettype, DELETED.TicketType, DELETED.isSubTransaction,DELETED.RequestID, DELETED.betid, DELETED.actual_stake
					
			INTO @tmpTransIDBatch(TransId,custid, Refno, bettype, TicketType, isSubTransaction,RequestID,betid,actual_stake)
			FROM #tmpTransId_VOID_RequestID t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
			-- backup into zzzbettrans for void transid
			INSERT INTO zzzbettrans (transid, custid, transdate, oddsid, hdp1, hdp2
					,odds, stake, STATUS, winlost, livehomescore, liveawayscore, liveindicator  
					,betteam, creator, refno, winlostdate, betfrom
					,betcheck
					,comstatus
					,checktime, matchid, bettype  
					,VoidingHistoryId
				)  
			SELECT b.transid, b.custid, GETDATE(), b.oddsid, b.hdp1, b.hdp2
				,b.odds, b.stake, b.STATUS, b.winlost, b.livehomescore, b.liveawayscore, b.liveindicator
				,b.betteam, b.creator,b.refno, b.winlostdate, b.betfrom
				,CASE 
					WHEN t.TicketType = 3 THEN @session -- original ticket & cashout bet ticket
					ELSE b.betcheck END AS betcheck 
				,CASE WHEN t.TicketType = 3 AND t.isSubTransaction = 1 THEN 'CO' ELSE b.comstatus END
				,b.checktime, b.matchid, b.bettype  
				,vd.VoidingHistoryId
			FROM @tmpTransIDBatch AS t 
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = t.TransId
				INNER JOIN @VoidingHistory_tmp vd ON t.RequestID = vd.RequestID
			
			-- Auto Void
			SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
									,CASE WHEN t.TicketType = 5 THEN t.Refno ELSE NULL END AS '@translogid'
									,t.betid AS '@betid'
									,CASE WHEN t.TicketType = 5 THEN 1 ELSE NULL END AS '@isMG'
									,CASE WHEN t.TicketType = 5 THEN t.actual_stake ELSE NULL END AS '@actual_stake'
									,t.isSubTransaction AS '@IsCashOutMember'
									FROM	@tmpTransIDBatch t
									FOR XML PATH('r'), ROOT('root')
								)
			EXEC dbo.TicketVoiding_Admin_VoidingTransId 
				@TransIds = @xmlTransId
				,@UserId = @UserId
				,@IssueTypeId = 11
				
			SET @xmlTransId = ''	 
			
		END
			
		-- Recal for ticket Lose by statuswinlost
		WHILE (1=1)
		BEGIN
			DELETE @tmpTransIDBatch
			
			UPDATE TOP(3000) t
				SET isFinish = 1
			OUTPUT deleted.transid
			INTO @tmpTransIDBatch(TransId)
			FROM #tmpTransId_Recalculate t 
			WHERE isFinish IS NULL
			
			IF @@ROWCOUNT = 0 BREAK
			
			SET @xmlTransId = ''
			
			SELECT @xmlTransId = (SELECT DISTINCT t.TransId AS '@transid'
									FROM	@tmpTransIDBatch t
									FOR XML PATH('r'), ROOT('root')
								)
								
			SET @TransIDList_tmp = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) FROM @tmpTransIDBatch FOR XML PATH('')),1,1,'')
			
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @TransIDList_tmp
				,@UserId = @UserId
				,@Username = @Username
				,@IP = @IP
				,@LogActionId = 90510
				,@IsLockMatch = 0
				,@ErrMsg = @ErrMsg OUTPUT
				,@ErrCode = @ErrCode OUTPUT
			
			IF @ErrCode = 0
			BEGIN
				EXEC dbo.TicketVoiding_ReCalculate_Single_Update 
					@TransIds = @xmlTransId
			END	
			
			SET @TransIDList_tmp = ''
			SET @xmlTransId = ''
				 
		END
		-- Pre cal 914
		IF EXISTS (SELECT TOP (1) 1 FROM @tmpCustCashOut)
		BEGIN
			BEGIN TRY				
				SET @CustIdsCashOut = STUFF((SELECT ',' + CAST(c.CustId AS VARCHAR(50))
												FROM (SELECT DISTINCT CustId FROM @tmpCustCashOut) c						    
												FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')	
																						    
				EXEC dbo.NAP_Admin_Calculate_914 
						@MatchId 	= @MatchID
						,@Action 	= 'VOID' -- use this option to limit cust need to update 914 only
						,@CustIds 	= @CustIdsCashOut				
			END TRY 
			BEGIN CATCH
				SELECT @ErrCode = 914
						, @ErrMsg = 'Called NAP_Admin_Calculate_914 with error.'
			END CATCH
		END
	END TRY
	BEGIN CATCH
		-- Capture Balance incase of failure
		INSERT INTO @AfterUpd(
			matchid
			,custid
			,balanceType		
			,walletType
			,bonusId
			,balance
		)
		SELECT	@matchid
				,b.custid
				,b.balanceType
				,b.WalletType
				,b.BonusID			
				,SUM(b.balance) AS balance
		FROM (	
			SELECT	b.custid
					,CASE 
						WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
						WHEN t.sporttype = 162 THEN 3 -- Casino
						ELSE 4  -- Others
					   END AS balanceType
					,CASE 
						WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,CASE
						WHEN t.isSubTransaction = 1 THEN 2
						ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
					,b.winlost - b.actual_stake + b.playercomm AS balance
					
			FROM #tmpTransId_VOID_RequestID t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
			UNION ALL
			SELECT	b.custid
					,t.balanceType
					,CASE 
						WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
						WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
						ELSE 0 END AS BonusID
					,CASE
						WHEN t.isSubTransaction = 1 THEN 2
						ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
					,b.winlost - b.actual_stake + b.playercomm AS balance
			FROM	#tmpTransId_Recalculate t
				INNER JOIN dbo.bettrans b WITH(NOLOCK)
					ON	t.TransId = b.transid
					
			UNION ALL
			
			SELECT b914.custid
					,1 AS balanceType
					,0 AS BonusId
					,2 AS WalletType
					,b914.winlost - b914.actual_stake + b914.playercomm AS balance
			FROM	@tmpCustCashOut c
				INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
					ON	b914.matchid = @MatchId
						AND b914.custid = c.CustId
						AND b914.bettype = 914
		)b
		GROUP BY b.custid
				,b.balanceType
				,b.BonusID
				,b.WalletType

		--UPDATE balance
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				@BalanceWalletBefore	= @beforeUpd
				, @BalanceWalletAfter	= @afterUpd
				, @ActionId				= 0	
		
		SELECT    @ErrCode = 1001017 
					,@ErrMsg = ERROR_MESSAGE()
	        
		DELETE tv
		FROM TicketVoiding_VoidingHistory tv WITH (ROWLOCK)
			INNER JOIN @VoidingHistory_tmp  t ON tv.VoidingHistoryId = t.VoidingHistoryId
			
		RETURN 
		 
	END CATCH

	-- PRE CAL 501 Cricket - charge comm
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTransId_VOID_RequestID WHERE bettype = 501)
	BEGIN
		DECLARE @TempData TABLE(RowId INT IDENTITY(1,1), MatchId INT, CustIds VARCHAR(MAX))		
		BEGIN TRY
			INSERT INTO @TempData(MatchId, CustIds)
			SELECT MatchId, STUFF((SELECT ',' + CAST(CustId AS VARCHAR(50))
									FROM #tmpTransId_VOID_RequestID tt where tt.MatchId = t.MatchId
									FOR XML PATH (''), ROOT('str'), TYPE ).value('/str[1]','VARCHAR(MAX)'), 1, 1, '')
			FROM #tmpTransId_VOID_RequestID t
			WHERE Bettype = 501
			GROUP BY MatchId

			IF EXISTS (SELECT TOP 1 1 FROM @TempData)
			BEGIN
				DECLARE @RowId INT, @MatchIdTmp INT, @CustIdsCricket VARCHAR(MAX)
				SELECT @RowId = 1
				WHILE EXISTS (SELECT TOP 1 1 FROM @TempData WHERE RowId = @RowId)
				BEGIN
					SELECT @MatchIdTmp = MatchId
						, @CustIdsCricket = CustIds
					FROM @TempData t WHERE RowId = @RowId
					SET @RowId = @RowId + 1
					
					EXEC dbo.NAP_Admin_Calculate_500 @MatchId	= @MatchIdTmp
						, @Action = 'VOID'
						, @CustIds = @CustIdsCricket
				END
			END
		END TRY 
		BEGIN CATCH
			SELECT	@ErrCode = 500
				,@ErrMsg = 'Called NAP_Admin_Calculate_500 with error.'
		END CATCH
	END

	IF (@isExistLucky3 = 1)
	BEGIN
		SELECT @Lucky3TransIDs = STUFF(
										(
											SELECT ',' + CAST(transid AS VARCHAR(MAX))
											FROM #tmpTransId_VOID_RequestID
											WHERE Bettype = 1600
											FOR XML PATH('')
										), 1, 1, '')
		
		INSERT INTO #Lucky3Matches(MatchID, Has1stPrize)
		SELECT	r.MatchId,
				MAX(CASE r.Prize WHEN 1 THEN 1 ELSE 0 END)
		FROM dbo.BetLucky3Result r WITH(NOLOCK)
		WHERE EXISTS (SELECT 1 FROM #tmpTransId_VOID_RequestID b WHERE b.transid = r.TransId AND b.Bettype = 1600)
			AND r.Bettype = 1601
		GROUP BY r.matchid
		
		--Delete data in betLucky3Result
		EXEC dbo.NAP_Admin_PreCalculate_s160 @MatchId = 0, @Mode = 'preCAL', @Action = 'VOID', @strVoidedTransId = @Lucky3TransIDs,
											@FirstBall = NULL, @SecondBall = NULL, @ThirdBall = NULL, @FirstPrizeMaxCount = NULL,
											@PrizeSettingId = NULL, @strCustSetting = NULL
		
		UPDATE l
		SET NumberOf1stPrize = d.NumberOf1stPrize,
			NumberOf2ndPrize = d.NumberOf2ndPrize,
			NumberOf3rdPrize = d.NumberOf3rdPrize
		FROM #Lucky3Matches l
			JOIN (
				SELECT  r.MatchId,
						SUM(CASE r.Prize WHEN 1 THEN Odds * Hits ELSE 0 END) AS NumberOf1stPrize,
						SUM(CASE r.Prize WHEN 2 THEN Odds * Hits ELSE 0 END) AS NumberOf2ndPrize,
						SUM(CASE r.Prize WHEN 3 THEN Odds * Hits ELSE 0 END) AS NumberOf3rdPrize
				FROM dbo.BetLucky3Result r WITH(NOLOCK)
				WHERE EXISTS (SELECT 1 FROM #Lucky3Matches l1 WHERE r.MatchId = l1.MatchID)
					AND r.Bettype = 1601
				GROUP BY r.MatchId
			) d ON l.MatchID = d.MatchId
		
		SELECT @Lucky3Matches = CAST((	SELECT	MatchID AS '@m',
												NumberOf1stPrize AS '@fn',
												NumberOf2ndPrize AS '@sn',
												NumberOf3rdPrize AS '@tn'
										FROM #Lucky3Matches
										FOR XML PATH('r'), ROOT('root'), TYPE) AS VARCHAR(MAX))
		
		--Update match prize count
		EXEC DBPRO.bodb02.dbo.NAP_Admin_Match_Update_s160 @Action = NULL, @IsAuto = 0, @strMatchInfo = @Lucky3Matches
		
	END
	
	--Get data after update
	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
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
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
		FROM dbo.bettrans b WITH(NOLOCK)
			INNER JOIN #tmpTransId_VOID_RequestID tmp 
			ON b.transId = tmp.transId AND b.custid = tmp.custid
		WHERE tmp.Bettype BETWEEN 1101 AND 1199
			OR tmp.bettype BETWEEN 81 AND 120 OR tmp.bettype BETWEEN 8101 AND 8120
			OR tmp.Bettype BETWEEN 1201 AND 1299
			OR tmp.bettype BETWEEN 2700 AND 2899
			OR b.bettype BETWEEN 1600 AND 1610
		GROUP BY b.custid, b.winlostdate, b.bettype
			,CASE
				WHEN tmp.Bettype BETWEEN 1101 AND 1199 THEN 1101
				WHEN tmp.Bettype BETWEEN 81 AND 120 OR tmp.Bettype BETWEEN 8101 AND 8120 THEN 81
				WHEN tmp.bettype BETWEEN 2700 AND 2899 THEN 1201
				WHEN b.bettype BETWEEN 1600 AND 1610 THEN 1600
				ELSE 1201
			END
	END
	
	--- Capture balance after
	INSERT INTO @AfterUpd(
		matchid
		,custid
		,balanceType		
		,walletType
		,bonusId
		,balance
	)
	SELECT	@matchid
			,b.custid
			,b.balanceType
			,b.WalletType
			,b.BonusID			
			,SUM(b.balance) AS balance
	FROM (	
		SELECT	b.custid
				,CASE 
					WHEN ((t.sporttype BETWEEN 1 AND 99 OR t.sporttype = 154) AND t.bettype NOT BETWEEN 801 AND 806) OR t.bettype IN (9,29,10) THEN 1 -- Sports
					WHEN t.sporttype = 162 THEN 3 -- Casino
					ELSE 4  -- Others
				   END AS balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
				
		FROM #tmpTransId_VOID_RequestID t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
		UNION ALL
		SELECT	b.custid
				,t.balanceType
				,CASE 
					WHEN t.isSubTransaction = 1 THEN 0 -- sub tickets always bet from cash wallet
					WHEN b.BonusID > 0 AND b.WalletType = 1 THEN b.BonusID 
					ELSE 0 END AS BonusID
				,CASE
					WHEN t.isSubTransaction = 1 THEN 2
					ELSE ISNULL(b.WalletType, 2) END AS WalletType -- sub tickets always bet from cash wallet
				,b.winlost - b.actual_stake + b.playercomm AS balance
		FROM	#tmpTransId_Recalculate t
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON	t.TransId = b.transid
				
		UNION ALL
		
		SELECT b914.custid
				,1 AS balanceType
				,0 AS BonusId
				,2 AS WalletType
				,b914.winlost - b914.actual_stake + b914.playercomm AS balance
		FROM	@tmpCustCashOut c
			INNER JOIN dbo.bettrans b914 WITH(NOLOCK)
				ON	b914.matchid = @MatchId
					AND b914.custid = c.CustId
					AND b914.bettype = 914
	)b
	GROUP BY b.custid
			,b.balanceType
			,b.BonusID
			,b.WalletType

	--UPDATE balance
	EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
			@BalanceWalletBefore	= @beforeUpd
			, @BalanceWalletAfter	= @afterUpd
			, @ActionId				= 0	

	IF(@isExistLC = 1 OR @isExistNG = 1 OR @isExistVS = 1 OR @IsExistVSBetradar = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistLucky3 = 1)
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
	
	-- get negative balance user list
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(a.custid AS VARCHAR(20)) + ','
	FROM	@BeforeUpd b
		INNER JOIN @AfterUpd a
			ON b.custid = a.custid
	WHERE	b.balance > a.balance

	EXEC dbo.NAP_CustNegativeBalance_Sel
		@CustIds = @CustIds
		,@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT

	-- Update BetTradeSellingCancelled information
	SET @CustIds = ''
	SELECT	@CustIds = @CustIds + CAST(t.custid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_VOID_RequestID t
	WHERE	t.bettype = 911
	GROUP BY t.custid

	EXEC dbo.TicketVoiding_BalanceMember_Select 
		@CustIds = @CustIds
		,@CustBalance = @CustBalance OUTPUT

	INSERT INTO @tmpBalanceMember (CustId, Balance)
	SELECT	T.C.value('./@c', 'int')
			,T.C.value('./@b', 'money')
	FROM	@CustBalance.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@CustBalance = NULL ))

	;WITH CTE_Source AS
		(
			SELECT	bts.TradeID AS TradeID
					,bts.TicketID AS [TicketID]					
					,'SB void ticket due to ' AS [Remark]
					,sub.awinlost AS [BTBuyBack]
					,0 AS [BTComission]
					,c.Balance AS [AfterBalance]
					,'SB' AS [Owner]
					,1 AS [Cancelled]
					,GETDATE() AS [ChangeDate]
					,GETDATE() AS [CreateDate]
			FROM	#tmpTransId_VOID_RequestID sub						 											 
				 INNER JOIN [dbo].[BetTradeSelling] bts WITH(NOLOCK)			    
						 ON bts.TicketID = sub.refno -- bettrade + cash-out
							AND CASE																				 
									WHEN sub.bettype = 911 -- cash-out													 
											THEN CASE
													WHEN bts.SoldTicketID = sub.transid THEN 1
													ELSE 0
												 END																							
									ELSE 1
								END = 1	
				 INNER JOIN @tmpBalanceMember c
						 ON sub.custid = c.custid						 							
			WHERE sub.BetType = 911
		)
		MERGE INTO [dbo].[BetTradeSellingCancelled] AS [Target]
		USING (SELECT * FROM CTE_Source) AS [Source]
		ON [Target].TradeID = [Source].TradeID
		WHEN MATCHED THEN UPDATE SET [Remark] = [Source].[Remark]
									,[BTBuyBack] = [Source].[BTBuyBack]
									,[BTComission] = [Source].[BTComission]
									,[AfterBalance] = [Source].[AfterBalance]
									,[Owner] = [Source].[Owner]
									,[Cancelled] = [Source].[Cancelled]
									,[ChangeDate] = [Source].[ChangeDate]										
		WHEN NOT MATCHED THEN INSERT(TradeID
									,[TicketID]										
									,[Remark]
									,[BTBuyBack]
									,[BTComission]
									,[AfterBalance]
									,[Owner]
									,[Cancelled]
									,[ChangeDate]
									,[CreateDate])
							  VALUES([Source].TradeID
									,[Source].[TicketID]										
									,[Source].[Remark]
									,[Source].[BTBuyBack]
									,[Source].[BTComission]
									,[Source].[AfterBalance]
									,[Source].[Owner]
									,[Source].[Cancelled]
									,[Source].[ChangeDate]
									,[Source].[CreateDate]); 

	IF @totalMainParlay = 0 OR @totalMainParlay <= @ThreadHold
	BEGIN
		IF @isExistOutright = 1 OR @isExistMG = 1 OR @isExistFM = 1 OR @isExistMatch = 1 OR @isExistNG = 1
				OR @isExistVS = 1 OR @isExistBB = 1 OR @IsExistParlayVSBetradar = 1 OR @isExistFM2 = 1
		BEGIN
			------ releasing single process
			EXEC dbo.NAP_Admin_CheckingProcess
				 @isExistOutright 			= @isExistOutright
				 , @isExistMG				= @isExistMG
				 , @isExistFM				= @isExistFM
				 , @isExistMatch			= @isExistMatch
				 , @isExistNG				= @isExistNG
				 , @isExistVS				= @isExistVS
				 , @isExistBB				= @isExistBB
				 , @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
				 , @isExistFM2				= @isExistFM2
				 , @IsReleased				= 1
		END

		IF @totalMainParlay	> 0 
		BEGIN
			------ releasing Refno parlay proccess
			EXEC dbo.NAP_Admin_CheckingProcess
				@IsLockingByRefno = 1
				,@Session	= @Session
				,@IsReleased = 1				
		END				
	END
	ELSE IF @totalMainParlay > @ThreadHold
	BEGIN
		------ releasing SD process
		EXEC dbo.NAP_Admin_CheckingProcess
					@isExistParlay 				= @isExistParlay
					, @isExistOutright 			= @isExistOutright
					, @isExistMG				= @isExistMG
					, @isExistFM				= @isExistFM
					, @isExistMatch				= @isExistMatch
					, @isExistNG				= @isExistNG
					, @isExistVS				= @isExistVS
					, @isExistBB				= @isExistBB
					, @IsExistParlayVSBetradar	= @IsExistParlayVSBetradar
					, @isExistFM2				= @isExistFM2
					, @IsReleased				= 1
	END

	------ releasing cash-out process
	EXEC dbo.NAP_Admin_CheckingCashOutProcess 
			@Mode = 'Original'
		  , @Action = 'Void'
		  , @IsReleased = 1  	

	--Insert data for TicketVoiding_Queue
	SET @EndTime = GETDATE()
	INSERT INTO dbo.TicketVoiding_Queue (
		RequestId
		,MatchId
		,VoidingHistoryId
		,TransIds
		,StatusId
		,UserId
		,Ip
		,VoidingTypeId
		,TotalTicket
		,Starttime
		,Exectime
		,Duration
	)
	SELECT	vh.RequestID
			,@MatchId
			,vh.VoidingHistoryId
			,vr.Transids
			,2 -- completed
			,@UserId
			,@IP
			,1
			,tmp.TotalTicket
			,@StartTime AS starttime
			,@StartTime AS Exectime
			,DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS Duration
	FROM @VoidingHistory_tmp vh
		INNER JOIN @AutoVoid_ValidRequest vr ON vh.RequestID = vr.RequestID
		CROSS APPLY (SELECT COUNT(1) AS TotalTicket
					FROM #tmpTransId_VOID_RequestID t
					WHERE t.RequestID = vh.RequestID) AS tmp
	
		
	-- Write Log
	DECLARE @allTransId_Void VARCHAR(MAX) = ''
	DECLARE @allTransId_Recal VARCHAR(MAX) = ''
	
	SELECT	@allTransId_Void = @allTransId_Void + CAST(transid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_VOID_RequestID
	
	SELECT	@allTransId_Recal = @allTransId_Recal + CAST(transid AS VARCHAR(20)) + ','
	FROM	#tmpTransId_Recalculate

	SET @EndTime = GETDATE()
	SET @VoidingHistoryIdList = STUFF((SELECT ',' + CAST(VoidingHistoryId AS VARCHAR(50)) FROM @VoidingHistory_tmp FOR XML PATH('')),1,1,'')
	SET @LogData = CAST((SELECT CASE WHEN @RequestId > 0 THEN @RequestId ELSE 0 END AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'
							,@IP AS '@IP'
							,@MatchId AS '@MatchId'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
								+ ' VoidingHistoryId: ' + @VoidingHistoryIdList
								+ ' Auto Void TransId: ' + @allTransId_Void
								+ ' Auto Recalculate TransId: ' + @allTransId_Recal
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))
	
	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #tblCashOutProcess
	DROP TABLE #tblMatchProcess
	DROP TABLE #inputRequestTransId
	DROP TABLE #tmpTransId_Recalculate
	DROP TABLE #tmpTransId_VOID_RequestID
	DROP TABLE #tmpRefCodeSummary_Recalculate
	DROP TABLE #tmpRefCodeSummary_VOID
	DROP TABLE #Transid_mark_tmp
	DROP TABLE #Transid_mark_void
	DROP TABLE #balanceGameAfter
	DROP TABLE #balanceGameBefore
	DROP TABLE #Lucky3Matches
	DROP TABLE #tblMatchParlayProcess

END

GO

