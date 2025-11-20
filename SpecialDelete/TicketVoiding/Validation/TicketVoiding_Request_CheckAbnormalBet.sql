/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_CheckAbnormalBet]
(
	 @TransIds					VARCHAR(MAX) = NULL
	,@RequestId					INT = 0
	,@ActionId					TINYINT	= 0
	,@FilterBy					TINYINT	= NULL
	,@SubIssueTypeId			TINYINT	= NULL
	,@IsRemoveCustomerClass201	BIT = 0
	,@IsRemoveCustomerClass4K	BIT = 0
	,@IsRemoveCreditCashService	BIT = 0			
	,@IsAddSettledTickets		BIT = 0
	,@IsVoidAllArchivedTickets	BIT = 0
	,@OnlineServerId			VARCHAR(10) = NULL --Ex:'0,1,2,3'
)
AS
/*  
	Created by: 20190625@Raymond.Le  
	Task: Validate matchId, betId of Abnormal bet
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02 
	Original:      

	Revisions:  
		- 20190625@Raymond.Le: Create new SP [Redmine: #115583]
		- 20190730@Raymond.Le: Incorporate BetBuilder [Redmine: #106898] 
		- 20191212@Max: AbnormalBet TVS [Redmine:#123691]
		- 20200405@Max: Enhance EKO Issue Type - [Redmine: #126418]
		- 20200213@Charles: Exclude bettypes of early settlement and fast market [Redmine:#127398]
		- 20200216@Max: Abnormal Void Bets Automation [Redmine: #128359]
		- 20200222@Helen: Hotfix - check early bettype for soccer only [Redmine: #127398]
		- 20200303@Max: Auto Void Winning Bets - Allow bettype of early settlement -  [Redmine: #129184]
		- 20200306@Max: Permission on add/void settled tickets [Redmine: #129902]
		- 20200320@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200413@Raymond: Not allow void if customer is VIP [Redmine: #131431]
		- 20200415@Raymond: Refactor query link server [Redmine: #131670]
		- 20200512@Charles: Auto Void Immediately [Redmine:#133705]
		- 20200625@Max: [TVS] Auto Void for remaining sports - [Redmine: #135574]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200907@Raymond: Disable LiveScore of Football sport [Redmine: #141058]
		- 20201103@Charles:  No need to check Live Score once add request for Baseball [Redmine: #144544]
		- 20201130@July: TVS - Check lock match before add request [Redmine: #143666]
		- 20210219@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075] 
		- 20210304@July: TVS - Abnormal Bet - Auto void before KO time - [Redmine: #150522] 
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210930@July: TVS - No need to check Live Score of Rugby and Ice Hockey sport [Redmine: #161877]
		- 20211005@Max: [TVS] Implement AB Whitelist - [Redmine:#161659]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20220119@July: Fix issue - Mix Parlay Error Cannot insert duplicate key [Redmine: #167724]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220414@Max: [TVS] Support AB Exclusion by sub issue type [Redmine: #170771]
		- 20220727@July: Change of TVS regarding to Scale out DBTrans [Redmine: #173229]
		- 20221007@July: TVS - Abnormalbet - No need to send Letstalk message if the request has UUS ticket [Redmine: #178321]
		- 20221021@July: TVS - WRONG check validation for transid 14 [Redmine: #179479]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230110@July: [TVS] Add more send Letstalk info when an abnormal request added [Redmine: #182392]
		- 20230116@July: [TVS] Exclude Customer Class = 4000 & Change CC=1 to CC=201 [Redmine: #182804]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230310@Max: [TVS] Support void Cricket tickets on TVS Abnormal Bet [Redmine: #168081]
		- 20230322@Max: [TVS] Exclude Field Hockey when checking live tickets [Redmine: #185235]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20231115@July: [TVS] Abnormal Bet - Export the list of tickets that the user inputs to a request before Save it [Redmine: #194133]
		- 20240102@July: [TVS] Recover Ticket - validation/loginfo of other Issuetype void (exclude issuetype recover) [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240305@July: [TVS] Abnormal Bet - Void settled tickets for Auto Void actions [Redmine: #195506]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]
		- 20240315@July: [TVS] Abnormal Bet - Support void System Parlay tickets [Redmine: #196462]
		- 20240412@Max: Abnormal Bet - Add request tick on REMOVE CC 40000 but tickets CC 4000 still add to request [Redmine: #203813]
		- 20240422@Max: [TVS] Abnormal Bet - Add single tickets of many matches to a request [Redmine: #196027]
		- 20250619@Lani: [TVS] Integrate - Agency Cash Service - Negative Balance - Abnormal Bet [Redmine: #225390]
		- 20250624@July: [TVS] Enhance TVS in case 1 or many siteDBs down - Scale out validate [Redmine: #228047]
		- 20250715@Lani: [TVS] Abnormal Bet - Send ticket of the username in AB Exception List to CTS [Redmine: #231465]
		- 20250815@Lani: [TVS] Return both running and settle tickets of sitedbdown [Redmine: #232580]
		- 20251007@July: [TVS] Update rules Send Letstalk [Redmine: #240950]
		- 20251006@July: [TVS] Abnormal Bet - Block void ticket after balance up date [Redmine: #238233]
		- 20251104@Lani: [TVS] Integrate Hybrid Parlay from Jacktime for Basketball sport [Redmine:#241502]

	Param's Explanation:
		+ @TransIds: Search by TransID
		+ @FilterBy: NULL: single ticket, 1: mix-parlay ticket, 2: system-parlay ticket, 4: hybrid parlay  ( BetBuilder+)
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds			 VARCHAR(MAX) = ''
			,@MovedTransIds				 VARCHAR(MAX) = ''
			,@SettledTransIds			 VARCHAR(MAX) = ''
			,@UnsupportedTransids		 VARCHAR(MAX) = ''
			,@ExistingReqTransIds		 VARCHAR(MAX) = ''
			,@TransIdsOfVIPCustomer		 VARCHAR(MAX) = ''
			,@NonLiveTransIds			 VARCHAR(MAX) = ''
			,@DifferentLiveScoreTransIds VARCHAR(MAX) = ''
			,@query						 NVARCHAR(MAX) = ''
			,@ExecuteSQL				 NVARCHAR(MAX) = ''
			,@IsHasWarningRemovedTickets BIT=0
			,@OldActionId				 TINYINT
			,@TransIdsOfCustomerClass201 VARCHAR(MAX) = ''
			,@TransIdsOfCustomerClass4K  VARCHAR(MAX) = ''
			,@TransIdsOfCreditCashService VARCHAR(MAX) = ''
			,@TransIdsOfSiteDBDown		 VARCHAR(MAX) = ''
			,@ABWhiteListTransIds		 VARCHAR(MAX) = ''
			,@MatchId					 INT = 0
			,@MarkTransIds 			     VARCHAR(MAX) =''
			,@UnmarkTransIds 			 VARCHAR(MAX) =''
			,@RemoveTransids 			 VARCHAR(MAX) ='' -- Ticket remove will re-cal (if any)
			,@TransInfoJson				 VARBINARY(MAX) = NULL
			,@Archived_FromDate			 DATETIME = NULL
			,@SiteDBDownInfoJson		 VARBINARY(MAX) = NULL
			,@SiteDBGroupID				 SMALLINT
			,@BeingBalanceUpDate		 VARCHAR(255)
			,@BalanceUpTransIds			 VARCHAR(MAX) = ''

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	SELECT @BeingBalanceUpDate = VValue
    FROM dbo.MBUSettings WITH (NOLOCK) 
	WHERE VName = 'BeingBalanceUpDate'

	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMatchId AS TABLE (MatchId INT)
	DECLARE @tmpMatchId_Info AS TABLE (MatchId INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT, matchcode NVARCHAR(50), eventdate DATETIME)
	DECLARE	@Letstalk_Info AS TABLE (MatchId INT, IsAllUUSTickets BIT, ListBettype VARCHAR(MAX),ListBetteam VARCHAR(MAX))
	DECLARE @tmp_OnlineServerId AS TABLE (ServerId SMALLINT)

	SET @Archived_FromDate = CONVERT(DATE, DATEADD(DAY, -7, GETDATE()))

	IF ISNULL(@OnlineServerId, '') <> ''
	BEGIN
		INSERT INTO @tmp_OnlineServerId (ServerId)
		SELECT value AS ServerId
		FROM STRING_SPLIT(@OnlineServerId, ',')
		WHERE value <> ''
	END

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	--get list VIP Account
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
								FROM dbo.Dep_CustVIP WITH (NOLOCK)	
								'
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
	INSERT INTO @VIPAccount_tmp(CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

	CREATE TABLE #tmpInputTransid_RemarkId (
		 Transid		BIGINT
		,RemarkId		INT	  /*  1: Invalid
								, 2: Moved or Duplicated 
								, 3: DifferentMatch
								, 4: Settled
								, 5: Unsupported
								, 6: ExistingReq
								, 7: NonLive
								, 8: DifferentLiveScore
								, 9: AB Exception TransIds
								, 10: SiteDB down TransIds
								, 11: Balance up Date
							  */
	)
	CREATE TABLE #inputTransid (transid BIGINT PRIMARY KEY)

	INSERT INTO #tmpInputTransid_RemarkId (transid)
	SELECT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	INSERT INTO #inputTransid (transid)
	SELECT DISTINCT transid
	FROM #tmpInputTransid_RemarkId

	CREATE TABLE #invalidTransId (transid BIGINT, TicketType INT)
	CREATE TABLE #TransidInRequest (TransId BIGINT PRIMARY KEY)
	CREATE TABLE #validTransId (
		transid						BIGINT PRIMARY KEY
		,StatusId					INT
		,bettype					SMALLINT
		,custId						INT
		,livehomescore				SMALLINT
		,liveawayscore				SMALLINT
		,liveindicator				BIT
		,matchid					INT
		,sporttype					SMALLINT
		,betfrom					NVARCHAR(4)
		,recommend					INT
		,mrecommend					INT
		,srecommend					INT
		,betteam					NVARCHAR(10)
		,CurrencyName				NVARCHAR(50)
		,IsVipMember				BIT DEFAULT(0)
		,IsCreditCashService		BIT DEFAULT(0)
		,CustomerClass				SMALLINT
		)
	CREATE TABLE #UnsupportedTransids(transid BIGINT PRIMARY KEY, IsSiteDBDown BIT DEFAULT(0))
	CREATE TABLE #ABWhiteListTransIds(transid BIGINT PRIMARY KEY)
	CREATE TABLE #LiveTransIds (
		TransId BIGINT PRIMARY KEY
		,IsNonLive BIT
		,IsDifferentScore BIT
		)
	CREATE TABLE #ABWhiteListCustIds (custid INT, AllowVoidSubType VARCHAR(200), IsAllowVoidVip BIT)
	CREATE TABLE #ABWhiteListCustIds_AllowVoid (custid INT)
	CREATE TABLE #tmpTransInfo(
	   matchid					INT
	  ,transid					BIGINT
      ,refno					BIGINT
	  ,custid					INT	
      ,hdp1						SMALLMONEY
	  ,hdp2						SMALLMONEY
	  ,livehomescore			SMALLINT
      ,liveawayscore			SMALLINT
      ,liveindicator			BIT
      ,odds						SMALLMONEY
	  ,oddsspread				MONEY
	  ,betfrom					NVARCHAR(4)
      ,bettype					SMALLINT
	  ,betteam					NVARCHAR(10)
      ,betcheck					NVARCHAR(50)
	  ,Status					NVARCHAR(10)
	  ,transdate				DATETIME
	  ,betid					BIGINT
	  ,Transdesc				NVARCHAR(1000)
	  ,statusID					TINYINT
	  ,srecommend				INT
	  ,mrecommend				INT
	  ,recommend				INT
	  ,creator					INT
	  ,WalletType				TINYINT
	  ,RefCode					BIGINT
	  ,stake					MONEY
	  ,oddstype					TINYINT
	  ,CurrencyName				NVARCHAR(50)
	  ,betdaqid					BIGINT
	  ,ExtraInfo				VARCHAR(1000)
	  ,statuswinlost			TINYINT
	  ,IsMoved14				BIT
	  ,winlost					MONEY
	  ,actual_stake				MONEY
	  ,winlostdate				SMALLDATETIME
	  ,modds					SMALLMONEY
	  ,IsMixParlay				BIT
	  ,SiteDBGroupID			SMALLINT
	  ,username					NVARCHAR(50)
	  ,homeid					INT
      ,awayid					INT
	  ,leagueid					INT
	  ,isNeutral				BIT
	  ,matchcode				NVARCHAR(50)
	  ,showtime					NVARCHAR(50)
      ,sporttype				SMALLINT
	  ,eventstatus				NVARCHAR(50)
	  ,CustomerClass			SMALLINT
	  ,IsCreditCashService		BIT DEFAULT(0)			
	  ,IsVipMember				BIT DEFAULT(0)
	  ,ChildMatchId				INT
	  ,IsSiteDBDown				BIT DEFAULT(0)
	  ,eventdate				DATETIME
	  ,TicketType				INT --1: Moved, 2: Balance up
	)
	--Search single tickets
	INSERT INTO #tmpTransInfo(
			matchid 
			,transid
			,custid                
			,transdate 
			,hdp1 
			,hdp2 
			,livehomescore 
			,liveawayscore 
			,liveindicator 
			,betteam 
			,creator 
			,refno 
			,betid 
			,bettype 
			,betdaqid 
			,betfrom 
			,statusID 
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,IsMoved14 
			,odds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,stake 
			,CurrencyName 
			,winlost        
			,actual_stake 
			,Status
			,modds 
			,SiteDBGroupID
			,winlostdate
		    ,IsSiteDBDown
		)
	SELECT b.matchid
		,b.TransId
		,b.custid
		,b.transdate
		,b.hdp1
		,b.hdp2
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.betteam
		,b.creator
		,b.refno
		,b.betid
		,b.bettype
		,b.betdaqid 
		,b.betfrom 
		,b.statusID 
		,b.recommend 
		,b.mrecommend 
		,b.srecommend 
		,b.statuswinlost 
		,CASE WHEN b.bettype = 29 THEN 1 ELSE 0 END AS IsMixParlay 
		,0 AS IsMoved14 
		,b.odds 
		,b.oddsspread
		,b.oddstype 
		,b.betcheck 
		,b.stake 
		,b.CurrencyName 
		,b.winlost        
		,b.actual_stake 
		,b.Status
		,b.modds 
		,b.SiteDBGroupID
		,b.winlostdate
		,CASE WHEN b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END IsSiteDBDown
	FROM #inputTransid t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t.transid
	WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				   WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
				   ELSE 0 END
		AND b.betfrom <> 'P'
		AND 1 = CASE WHEN @FilterBy IS NULL AND b.bettype <> 29 THEN 1
			         WHEN @FilterBy = 1 AND b.bettype = 29 AND b.betteam = '1' AND ISNULL(b.oddsspread,0) <> 3 THEN 1
					 WHEN @FilterBy = 2 AND b.bettype = 29 AND b.betteam <> '1' AND ISNULL(b.oddsspread,0) <> 3 THEN 1
					 WHEN @FilterBy = 4 AND b.bettype = 29 AND ISNULL(b.oddsspread,0) = 3 THEN 1
				     ELSE 0 END
		AND 1 = CASE WHEN b.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID IN (SELECT ServerId FROM @tmp_OnlineServerId) THEN 1
					 WHEN b.SiteDBGroupID NOT IN (SELECT ServerId FROM @tmp_OnlineServerId) THEN 1  -- Get ticket sitedb down
					 ELSE 0 END

	IF EXISTS (SELECT TOP(1) 1 
				FROM #inputTransid t
					INNER JOIN dbo.bettrans14 b14 WITH (NOLOCK) ON b14.transid = t.transid
			)
	BEGIN
		INSERT INTO #tmpTransInfo(
			matchid 
			,transid
			,custid                
			,transdate 
			,hdp1 
			,hdp2 
			,livehomescore 
			,liveawayscore 
			,liveindicator 
			,betteam 
			,creator 
			,refno 
			,betid 
			,bettype 
			,betdaqid 
			,betfrom 
			,statusID 
			,recommend 
			,mrecommend 
			,srecommend 
			,statuswinlost 
			,IsMixParlay 
			,IsMoved14 
			,odds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,stake 
			,CurrencyName 
			,winlost        
			,actual_stake 
			,Status
			,modds 
			,SiteDBGroupID
			,winlostdate
		    ,IsSiteDBDown
			,TicketType
		)
		SELECT b.matchid
			,b.TransId
			,b.custid
			,b.transdate
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.betteam
			,b.creator
			,b.refno
			,b.betid
			,b.bettype
			,b.betdaqid 
			,b.betfrom 
			,b.statusID 
			,b.recommend 
			,b.mrecommend 
			,b.srecommend 
			,b.statuswinlost 
			,CASE WHEN b.bettype = 29 THEN 1 ELSE 0 END AS IsMixParlay 
			,1 AS IsMoved14 
			,b.odds 
			,b.oddsspread
			,b.oddstype 
			,b.betcheck 
			,b.stake 
			,b.CurrencyName 
			,b.winlost        
			,b.actual_stake 
			,b.Status
			,b.modds 
			,b.SiteDBGroupID
			,b.winlostdate
			,CASE WHEN b.SiteDBGroupID = @SiteDBGroupID THEN 0 ELSE 1 END IsSiteDBDown
			,CASE WHEN @IsVoidAllArchivedTickets = 0 AND b.winlostdate < @Archived_FromDate THEN 1 
				  WHEN @IsVoidAllArchivedTickets = 1 AND @BeingBalanceUpDate IS NOT NULL AND b.winlostdate < @BeingBalanceUpDate THEN 2
				  ELSE NULL END AS TicketType
		FROM #inputTransid t
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.TransId = t.transid
		WHERE 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1-- reject, void, refund
				       WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
				       ELSE 0 END
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN @FilterBy IS NULL AND b.bettype <> 29 THEN 1
			             WHEN @FilterBy = 1 AND b.bettype = 29 AND b.betteam = '1' AND ISNULL(b.oddsspread,0) <> 3 THEN 1
					     WHEN @FilterBy = 2 AND b.bettype = 29 AND b.betteam <> '1' AND ISNULL(b.oddsspread,0) <> 3 THEN 1
						 WHEN @FilterBy = 4 AND b.bettype = 29 AND ISNULL(b.oddsspread,0) = 3 THEN 1
				         ELSE 0 END
			AND 1 = CASE WHEN b.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID IN (SELECT ServerId FROM @tmp_OnlineServerId) THEN 1
						 WHEN b.SiteDBGroupID NOT IN (SELECT ServerId FROM @tmp_OnlineServerId) THEN 1  -- Get ticket sitedb down
					     ELSE 0 END
	END

	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransInfo WHERE bettype NOT IN (9, 29) AND (IsMoved14 = 0)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,eventstatus = ISNULL(m.eventstatus,'')
			--Update Main MatchId for child match cricket/baseball (Sporttype In (50,8))
			,d.matchid = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN m.ParentID ELSE d.matchid END
			,d.ChildMatchId = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN m.matchid ELSE NULL END
			,eventdate = m.eventdate
		FROM #tmpTransInfo d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29)
	END
	
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransInfo WHERE bettype NOT IN (9, 29) AND (IsMoved14 = 1)))
	BEGIN
		UPDATE d
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,eventstatus = ISNULL(m.eventstatus,'')
			--Update Main MatchId for child match cricket/baseball (Sporttype In (50,8))
			,d.matchid = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN m.ParentID ELSE d.matchid END
			,d.ChildMatchId = CASE WHEN m.sporttype IN (50,8) AND m.ChildMatchType = 200 THEN m.matchid ELSE NULL END
			,eventdate = m.eventdate
		FROM #tmpTransInfo d
			INNER JOIN dbo.match14 m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29)
	END

	UPDATE al
		SET username = ci.username
		   ,CustomerClass = CASE WHEN ci.CustomerClass IN (201, 4000) THEN ci.CustomerClass ELSE NULL END 
		   ,IsVipMember = CASE WHEN vip.CustID IS NOT NULL THEN 1 ELSE 0 END
		   ,IsCreditCashService = CASE WHEN cs.CustID IS NOT NULL AND s.custid IS NULL THEN 1 ELSE 0 END
	FROM	#tmpTransInfo al
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
			ON al.custid = ci.custid
		LEFT JOIN CustDB.dbo.CustProductStatus cs WITH (NOLOCK)
			ON al.custid = cs.CustID AND cs.ServiceType = 1
		LEFT JOIN CustDB.dbo.Dep_CustSuper s WITH (NOLOCK)
			ON al.srecommend = s.custid
		LEFT JOIN @VIPAccount_tmp vip ON al.custid = vip.CustID

	--Duplicated Transids
	UPDATE t
	SET t.RemarkId = 2
	FROM #tmpInputTransid_RemarkId t
		WHERE EXISTS (
			SELECT i.transid
			FROM #tmpInputTransid_RemarkId i
				INNER JOIN #tmpTransInfo x ON i.Transid = x.Transid
			WHERE i.Transid = t.Transid
			GROUP BY i.Transid
			HAVING COUNT(1) >= 2
		)
	
	--Remove CC201 & CC4000, transid of credit cash service in list transids insert into request
	DELETE v
	FROM #tmpTransInfo v 
	WHERE 1 = CASE WHEN @IsRemoveCustomerClass201 = 1 AND v.CustomerClass = 201 THEN 1
					WHEN @IsRemoveCustomerClass4K = 1 AND v.CustomerClass = 4000 THEN 1
					WHEN @IsRemoveCreditCashService = 1 AND v.IsCreditCashService = 1 THEN 1
			ELSE 0 END
	
	IF @FilterBy IS NULL
	BEGIN
		-- get unsuppored transid
		DELETE FROM #tmpTransInfo
			OUTPUT DELETED.transid, DELETED.IsSiteDBDown INTO #UnsupportedTransids (transid, IsSiteDBDown)
		WHERE bettype NOT IN (SELECT bettype FROM @bettype_tmp)

		SELECT @UnsupportedTransids = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #UnsupportedTransids t
										WHERE t.IsSiteDBDown = 0
										FOR XML PATH('')), 1, 1, ''), '')
	
		UPDATE t
		SET t.RemarkId = 5
		FROM #tmpInputTransid_RemarkId t
			INNER JOIN #UnsupportedTransids u ON t.Transid = u.transid AND u.IsSiteDBDown = 0
	END

	BEGIN
		DECLARE @tmpSiteDBDownInfo TABLE (
			MatchId INT,
			TransId BIGINT,
			IsMixParlay BIT,
			SiteDBGroupID SMALLINT,
			isMarked BIT
		);
		DECLARE @SingleCountSiteDBDown INT
		       ,@ParlayCountSiteDBDown INT
		
		INSERT INTO @tmpSiteDBDownInfo (MatchId, TransId, IsMixParlay, SiteDBGroupID, isMarked)
		SELECT ISNULL(ChildMatchId, MatchId) AS MatchId, TransId, IsMixParlay, SiteDBGroupID, CASE WHEN statusID IN (0,1) THEN 1 ELSE 0 END AS isMarked
		FROM #tmpTransInfo t
		WHERE IsSiteDBDown = 1 AND TicketType IS NULL
			AND t.transid IN (SELECT transid FROM #tmpInputTransid_RemarkId WHERE RemarkId IS NULL)

		UPDATE t
		SET t.RemarkId = 10
		FROM #tmpInputTransid_RemarkId t
		WHERE t.Transid IN (SELECT Transid FROM @tmpSiteDBDownInfo)

		SELECT @TransIdsOfSiteDBDown = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM @tmpSiteDBDownInfo t
										FOR XML PATH('')), 1, 1, ''), '')

		SELECT @SingleCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 0 THEN 1 ELSE NULL END)
		      ,@ParlayCountSiteDBDown = COUNT(CASE WHEN IsMixParlay = 1 THEN 1 ELSE NULL END)
		FROM @tmpSiteDBDownInfo

	END

	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,StatusId
		,bettype
		,custId
		,livehomescore
		,liveawayscore
		,liveindicator
		,matchid
		,sporttype
		,betfrom
		,recommend
		,mrecommend
		,srecommend
		,betteam
		,CurrencyName
		,IsVipMember
		,CustomerClass
		,IsCreditCashService
		)
	SELECT b.transid
		,b.statusID
		,b.bettype
		,b.custid
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,b.matchid
		,b.sporttype
		,b.betfrom
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,b.betteam
		,CurrencyName
		,b.IsVipMember
		,b.CustomerClass
		,b.IsCreditCashService
	FROM #tmpTransInfo b
	WHERE IsSiteDBDown = 0 AND TicketType IS NULL

	INSERT INTO #TransidInRequest (TransId)
	SELECT DISTINCT tmp.transid
	FROM DBCTG.bodb02.dbo.TicketVoiding_Request r WITH (NOLOCK)
		CROSS APPLY (
					SELECT TransId
					FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
					WHERE RequestId = r.RequestId AND SiteDBGroupID = @SiteDBGroupID
				) AS tmp
	WHERE  r.RequestId <> @RequestId 
		AND (r.ActionId NOT IN (2) AND r.IssueTypeId NOT IN (22))

	-- get invalid or moved transId
	INSERT INTO #invalidTransId (transid, TicketType)
	SELECT temp.transid
		  ,ISNULL(TicketType,0) AS TicketType
	FROM #inputTransid AS temp
		OUTER APPLY (
		SELECT TicketType
		FROM #tmpTransInfo
		WHERE transid = temp.transid 
		) bm
	WHERE NOT EXISTS (SELECT 1 FROM #validTransId 
					  WHERE transid = temp.transid 
					  AND 1 = CASE WHEN @ActionId = 1 AND StatusId IN (111,112,113) THEN 0 ELSE 1 END)
		AND temp.transid NOT IN ( SELECT TransId FROM #tmpInputTransid_RemarkId WHERE RemarkId IS NOT NULL)
		AND temp.transid NOT IN ( SELECT TransId FROM #TransidInRequest)

	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
									FROM #invalidTransId
									WHERE TicketType = 0
									FOR XML PATH('')), 1, 1, ''), '')

	SELECT @MovedTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
								FROM #invalidTransId
								WHERE TicketType = 1
								FOR XML PATH('')), 1, 1, ''), '')

	SELECT @BalanceUpTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
								FROM #invalidTransId
								WHERE TicketType = 2
								FOR XML PATH('')), 1, 1, ''), '')

	UPDATE t
	SET t.RemarkId = CASE WHEN v.TicketType = 1 THEN 2
						  WHEN v.TicketType = 2 THEN 11
						  ELSE 1 END
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #invalidTransId v ON t.Transid = v.transid
	
	IF @ActionId <> 2
	BEGIN
		SELECT @SettledTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
										FROM #validTransId AS v
										WHERE v.StatusId NOT IN (0,1)
										FOR XML PATH('')), 1, 1, ''), '')
		
		UPDATE t
		SET t.RemarkId = CASE WHEN @IsAddSettledTickets = 1 AND @ActionId <> 1 AND t.RemarkId IS NOT NULL THEN t.RemarkId
							  WHEN @IsAddSettledTickets = 1 AND @ActionId <> 1 AND t.RemarkId IS NULL THEN NULL
							  ELSE 4 END --Settled
		FROM #tmpInputTransid_RemarkId t
			INNER JOIN #validTransId v ON t.Transid = v.transid
		WHERE v.StatusId NOT IN (0,1)

		SELECT @ExistingReqTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #inputTransid t 
											INNER JOIN #TransidInRequest tr ON t.transid = tr.TransId
										FOR XML PATH('')), 1, 1, ''), '')

		UPDATE t
		SET t.RemarkId = 6 --Existing Request
		FROM #tmpInputTransid_RemarkId t
			INNER JOIN #TransidInRequest v ON t.Transid = v.transid

		SELECT @TransIdsOfVIPCustomer = ISNULL(STUFF((SELECT ', ' + CAST(v.transid AS VARCHAR(50))
											FROM #validTransId AS v				
											WHERE v.IsVipMember = 1
											FOR XML PATH('')), 1, 1, ''), '')

		-- Check validation for the ticket that has Customer Class = 201 & Customer Class = 4000
		SELECT @TransIdsOfCustomerClass201 = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
												FROM #validTransId AS v	
												WHERE v.CustomerClass = 201
												FOR XML PATH('')), 1, 1, ''), '')

		SELECT @TransIdsOfCustomerClass4K = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
												FROM #validTransId AS v	
												WHERE v.CustomerClass = 4000
												FOR XML PATH('')), 1, 1, ''), '')
		
		--Get ticket of agency cash service customer (service type = 1)
		SELECT @TransIdsOfCreditCashService = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
												FROM #validTransId AS v	
												WHERE v.IsCreditCashService = 1
												FOR XML PATH('')), 1, 1, ''), '')
	END
	
	--Check AB White List Invalid Transid
	BEGIN
		-- get ABWhiteList Cust
		INSERT #ABWhiteListCustIds (custid, AllowVoidSubType, IsAllowVoidVip)
		SELECT t.custId, ab.AllowVoidSubType, ab.IsAllowVoidVip 
		FROM (
			SELECT DISTINCT custId, recommend, mrecommend, srecommend
			FROM #validTransId
			)t
			CROSS APPLY (
						SELECT TOP(1) a.AllowVoidSubType, a.IsAllowVoidVip					
						FROM DBCTG.bodb02.dbo.TicketVoiding_ABWhiteList a WITH (NOLOCK)	
						WHERE a.CustID IN (t.CustID, t.recommend, t.mrecommend, t.srecommend)
						ORDER BY a.LevelId ASC
				)ab

		INSERT INTO #ABWhiteListCustIds_AllowVoid (custid)
		SELECT t.custid
		FROM #ABWhiteListCustIds t
			LEFT JOIN @VIPAccount_tmp v ON v.CustID= t.CustID
		WHERE CHARINDEX(',' + CONVERT(VARCHAR(5), @SubIssueTypeId) + ',', ',' + t.AllowVoidSubType + ',') > 0
			AND 1 = CASE WHEN v.CustID IS NULL then 1
						WHEN v.CustID IS NOT NULL AND ISNULL(t.IsAllowVoidVip,0) = 1 THEN 1
					ELSE 0 END
		
		IF EXISTS (SELECT TOP(1) 1 FROM #ABWhiteListCustIds_AllowVoid)
		BEGIN
			DELETE t1
			FROM #ABWhiteListCustIds t1
				INNER JOIN #ABWhiteListCustIds_AllowVoid t2 ON t2.custid = t1.custid
		END

		IF EXISTS (SELECT TOP(1) 1 FROM #ABWhiteListCustIds)
		BEGIN
			INSERT INTO #ABWhiteListTransIds (transid)
			SELECT t.transid
			FROM #validTransId t
				INNER JOIN #ABWhiteListCustIds c ON c.CustID = t.custId

			SELECT @ABWhiteListTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
											FROM #ABWhiteListTransIds t
											FOR XML PATH('')), 1, 1, ''), '')
		END
	END
	
	IF @FilterBy IS NULL AND @ActionId IN (4) -- Auto Void All (Instant)
	BEGIN
		-- get non-live and different score transids
		INSERT #LiveTransIds(TransId, IsNonLive, IsDifferentScore)
		SELECT t.transid
			, CASE WHEN m.GlobalShowTime < GETDATE() AND t.liveindicator = 0 THEN 1 ELSE 0 END
			, CASE
				WHEN m.sporttype IN (1,49,51) AND t.liveindicator = 1
					AND (m.livehomescore <> t.livehomescore OR m.liveawayscore <> t.liveawayscore)
				THEN 1 ELSE 0
			END
		FROM #validTransId t
			OUTER APPLY ( 	SELECT GlobalShowTime, livehomescore, liveawayscore, sporttype    
							FROM dbo.match WITH (NOLOCK)
							WHERE matchid = t.matchid
							
							UNION 
							SELECT GlobalShowTime, livehomescore, liveawayscore, sporttype    
							FROM dbo.match14 WITH (NOLOCK)
							WHERE matchid = t.matchid
						) m

		SELECT @NonLiveTransIds = ISNULL(STUFF((SELECT ',' + CAST(lt.transid AS VARCHAR(50))
										FROM #LiveTransIds lt
										WHERE lt.IsNonLive = 1
										FOR XML PATH('')), 1, 1, ''), '')

		SELECT @DifferentLiveScoreTransIds = ISNULL(STUFF((SELECT ',' + CAST(lt.transid AS VARCHAR(50))
														FROM #LiveTransIds lt
														WHERE lt.IsDifferentScore = 1
														FOR XML PATH('')), 1, 1, ''), '')
		
		UPDATE t
		SET t.RemarkId = CASE WHEN IsNonLive = 1 THEN 7 
							  WHEN IsDifferentScore = 1 THEN 8 
							  ELSE t.RemarkId END
		FROM #tmpInputTransid_RemarkId t
			INNER JOIN #LiveTransIds v ON t.Transid = v.transid 
	
	END

	UPDATE t
		SET t.RemarkId = 9 --AB Exception TransIds
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #ABWhiteListTransIds v ON t.Transid = v.transid  

	/******************************* MARK/ UNMARK/ REMOVE TICKETS **************************************/

	IF @FilterBy IS NULL
	BEGIN
		INSERT INTO @tmpMatchId_Info (MatchId, homeid, awayid, leagueid, sporttype, matchcode, eventdate)
		SELECT DISTINCT v.matchid, homeid, awayid, leagueid, v.sporttype, matchcode, eventdate
		FROM #validTransId v
			INNER JOIN #tmpTransInfo t ON v.matchid = t.matchid
	END
	ELSE
	BEGIN
		INSERT INTO @tmpMatchId_Info (MatchId)
		SELECT 29 AS MatchId
	END

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		INSERT INTO @tmpMarkTransId (TransId)
		SELECT transid
		FROM #validTransId WHERE StatusId IN (0,1)		
	END
	ELSE IF @RequestId <> 0
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM DBCTG.bodb02.dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Remove transid from request => unmark ticket & re-cal ticket
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT transid 
			FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
			WHERE NOT EXISTS( SELECT TOP 1 1 FROM #validTransId it WHERE rdt.TransId=it.transid) -- exist vs input
					AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
					AND rdt.RequestId = @RequestId AND rdt.SiteDBGroupID = @SiteDBGroupID
			
			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT transid 
			FROM #validTransId v
			WHERE v.StatusId IN (0,1) 
				AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = v.TransId)-- exist in # request
				AND NOT EXISTS ( SELECT TOP 1 1 FROM @tmpUnmarkTransId um WHERE um.TransId = v.transid)

		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT transid
			FROM #validTransId WHERE StatusId IN (0,1)

		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId --Take note
		BEGIN
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT rdt.TransId
			FROM DBCTG.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
			WHERE rdt.RequestId = @RequestId AND rdt.SiteDBGroupID = @SiteDBGroupID

		END
	END

	SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,''),'')

	SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpUnmarkTransId
											FOR XML PATH('')), 1,1,''),'')

	IF @UnmarkTransIds <> ''
	BEGIN
		SET @IsHasWarningRemovedTickets = 1
				
		SELECT @RemoveTransids = @UnmarkTransIds
	END

	/*****************Return table **************************/
	--1. Info match table
	SELECT matchid, homeid, awayid, leagueid, sporttype, matchcode, eventdate
	FROM @tmpMatchId_Info
		
	--2. Validate Table
	SELECT   @MovedTransIds AS MovedTransIds
			,@InvalidTransIds AS InvalidTransIds
			,@BalanceUpTransIds AS BalanceUpTransIds
			,@SettledTransIds AS SettledTransIds
			,@ExistingReqTransIds AS ExistingReqTransIds
			,@UnsupportedTransids AS UnsupportedTransids
			,@TransIdsOfVIPCustomer AS TransIdsOfVIPCustomer
			,@NonLiveTransIds AS NonLiveTransIds
			,@DifferentLiveScoreTransIds AS DifferentLiveScoreTransIds
			,@TransIdsOfCustomerClass201 AS TransIdsOfCustomerClass201
			,@TransIdsOfCustomerClass4K AS TransIdsOfCustomerClass4K
			,@TransIdsOfCreditCashService AS TransIdsOfCreditCashService
			,@TransIdsOfSiteDBDown AS TransIdsOfSiteDBDown
			,@ABWhiteListTransIds AS ABWhiteListTransIds
			,@IsHasWarningRemovedTickets AS IsHasWarningRemovedTickets

		--3. List ticket unmark/mark & Transinfo table (if any)
	SET @TransInfoJson = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #validTransId t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))
	
	--List ticket insert table TicketVoiding_PendingMarkTickets
	SET @SiteDBDownInfoJson = COMPRESS((SELECT MatchId AS 'mid'
		,transid AS 't'
		,IsMixParlay AS 'isP'
		,SiteDBGroupID AS 'sitedb'
		,isMarked AS 'isMarked'
	FROM @tmpSiteDBDownInfo 
	FOR JSON PATH))

	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@RemoveTransids AS RemoveTransids -- Ticket remove -> re-cal
		  ,@MarkTransIds AS MarkTransIds
		  ,CONVERT(VARCHAR(MAX), @TransInfoJson, 1) AS TransInfoJson
		  ,CONVERT(VARCHAR(MAX), @SiteDBDownInfoJson, 1) AS SiteDBDownInfoJson 
		  ,@SingleCountSiteDBDown AS SingleCount
		  ,@ParlayCountSiteDBDown AS ParlayCount
	
	--5. Export Ticket that the user inputs table [#194133]
	SELECT  t.transid 
		,t.RemarkId 
		,s.matchid
		,s.homeid    
		,s.awayid    
		,s.leagueid  
		,s.isNeutral 
		,s.matchcode
		,s.sporttype
		,s.transdate
		,s.custid		
		,s.username	
		,s.bettype
		,s.odds
		,s.OddsType
		,s.Stake
		,s.WinLost - s.actual_stake AS WinLost
		,s.statusID
		,s.status
		,s.currencyname
		,s.betteam
		,s.hdp1
		,s.hdp2
		,s.livehomescore
		,s.liveawayscore
		,s.LiveIndicator AS IsLiveIndicator
		,s.oddsspread
		,s.betid
		,s.betcheck
		,s.IsMixParlay
		,s.SiteDBGroupID
		,s.IsVipMember
		,s.CustomerClass
		,s.IsCreditCashService
	FROM #tmpInputTransid_RemarkId t
		LEFT JOIN #tmpTransInfo s ON t.transid = s.transid

	--6. Info for send letstalk when add request
	INSERT INTO @Letstalk_Info (MatchId, IsAllUUSTickets, ListBettype, ListBetteam)
	SELECT m.MatchId
		,CASE WHEN t1.cnt_ticket = t1.cnt_UUSticket THEN 1 ELSE 0 END IsAllUUSTickets
		,ISNULL(STUFF((SELECT DISTINCT ', ' + CAST(b.typenamee AS VARCHAR(100))
			FROM #validTransId AS v
			INNER JOIN dbo.bettype b WITH(NOLOCK) ON v.bettype = b.typeid
			WHERE v.bettype <> 29 AND v.matchid = m.MatchId
			FOR XML PATH('')), 1, 1, ''), '')
		,ISNULL(STUFF((SELECT DISTINCT ', ' + CAST(v.betteam AS VARCHAR(100))
			FROM #validTransId AS v
			WHERE v.bettype <> 29 AND v.matchid = m.MatchId
			FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 2, ''), '')
	FROM @tmpMatchId_Info m
	OUTER APPLY (
		SELECT COUNT(1) cnt_ticket
			  ,SUM(CASE WHEN t.CurrencyName = 'UUS' THEN 1 ELSE 0 END) AS cnt_UUSticket
		FROM #validTransId t
		WHERE t.matchid = m.MatchId
	)t1

	SELECT l.MatchId, l.IsAllUUSTickets, l.ListBettype, l.ListBetteam
	FROM @Letstalk_Info l

	DROP TABLE #inputTransid
	DROP TABLE #validTransId
	DROP TABLE #TransidInRequest
	DROP TABLE #UnsupportedTransids
	DROP TABLE #LiveTransIds
	DROP TABLE #ABWhiteListTransIds
	DROP TABLE #ABWhiteListCustIds
	DROP TABLE #ABWhiteListCustIds_AllowVoid
	DROP TABLE #tmpTransInfo
	DROP TABLE #invalidTransId
	DROP TABLE #tmpInputTransid_RemarkId
END
