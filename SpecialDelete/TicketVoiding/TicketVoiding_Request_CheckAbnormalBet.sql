/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_CheckAbnormalBet]
(
	 @TransIds					VARCHAR(MAX) = NULL
	,@RequestId					INT = 0
	,@ActionId					TINYINT	= 0
	,@FilterBy					TINYINT	= NULL
	,@SubIssueTypeId			TINYINT	= NULL
	,@IsRemoveCustomerClass201	BIT = 0
	,@IsRemoveCustomerClass4K	BIT = 0
	,@TransInfoJson				VARCHAR(MAX) = NULL
)
AS
/*  
	Created by: 20190625@Raymond.Le  
	Task: Validate matchId, betId of Abnormal bet
	DB: DBCTG/bodb02   
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
		
	Param's Explanation:
		+ @TransIds: Search by TransID
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds			 VARCHAR(MAX) = ''
			,@MovedTransIds				 VARCHAR(MAX) = ''
			,@DifferentMatchTransIds     VARCHAR(MAX) = '' 
			,@SettledTransIds			 VARCHAR(MAX) = ''
			,@UnsupportedTransids		 VARCHAR(MAX) = ''
			,@ExistingReqTransIds		 VARCHAR(MAX) = ''
			,@TransIdsOfVIPCustomer		 VARCHAR(MAX) = ''
			,@NonLiveTransIds			 VARCHAR(MAX) = ''
			,@DifferentLiveScoreTransIds VARCHAR(MAX) = ''
			,@query						 NVARCHAR(MAX) = ''
			,@ExecuteSQL				 NVARCHAR(MAX) = ''
			,@IsHasWarningRemovedTickets BIT=0
			,@IsHasUUSTickets			 BIT=0
			,@OldActionId				 TINYINT
			,@TransIdsOfCustomerClass201 VARCHAR(MAX) = ''
			,@TransIdsOfCustomerClass4K  VARCHAR(MAX) = ''
			,@ABWhiteListTransIds		 VARCHAR(MAX) = ''
			,@MatchId					 INT = 0
			,@MarkTransIds 			     VARCHAR(MAX) =''
			,@UnmarkTransIds 			 VARCHAR(MAX) =''
			,@RemoveTransids 			 VARCHAR(MAX) ='' -- Ticket remove will re-cal (if any)
			,@ListBettype 				 VARCHAR(MAX) =''
			,@ListBetteam 				 VARCHAR(MAX) =''
			,@TransInfoJson_Output		 VARBINARY(MAX) = NULL


	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @CustId_tmp AS TABLE (CustID INT, recommend INT, mrecommend INT, srecommend INT)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT, CustID INT)
	DECLARE @tmpMatchId AS TABLE (MatchId INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT, matchcode NVARCHAR(50))

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

	CREATE TABLE #invalidTransId (transid BIGINT, isMoved BIT)
	CREATE TABLE #TransidInRequest (TransId BIGINT PRIMARY KEY)
	CREATE TABLE #validTransId (
		transid			BIGINT PRIMARY KEY
		,isInMatch		BIT
		,StatusId		INT
		,bettype		SMALLINT
		,custId			INT
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
		,liveindicator	BIT
		,matchid		INT
		,sporttype		SMALLINT
		,betfrom		NVARCHAR(4)
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,betteam		NVARCHAR(10)
		,CurrencyName	NVARCHAR(50)
		,IsVipMember	BIT DEFAULT(0)
		,CustomerClass	SMALLINT
		)
	CREATE TABLE #DuplicatedTransids(transid BIGINT PRIMARY KEY)
	CREATE TABLE #UnsupportedTransids(transid BIGINT PRIMARY KEY)
	CREATE TABLE #ABWhiteListTransIds(transid BIGINT PRIMARY KEY)
	CREATE TABLE #LiveTransIds (
		TransId BIGINT PRIMARY KEY
		,IsNonLive BIT
		,IsDifferentScore BIT
		)
	CREATE TABLE #ABWhiteListCustIds (custid INT, AllowVoidSubType VARCHAR(200), IsAllowVoidVip BIT)
	CREATE TABLE #ABWhiteListCustIds_AllowVoid (custid INT)
	CREATE TABLE #tmpTransInfo(
	   matchid			INT
	  ,transid			BIGINT
      ,refno			BIGINT
	  ,custid			INT	
      ,hdp1				SMALLMONEY
	  ,hdp2				SMALLMONEY
	  ,livehomescore	SMALLINT
      ,liveawayscore	SMALLINT
      ,liveindicator	BIT
      ,odds				SMALLMONEY
	  ,oddsspread		MONEY
	  ,betfrom			NVARCHAR(4)
      ,bettype			SMALLINT
	  ,betteam			NVARCHAR(10)
      ,betcheck			NVARCHAR(50)
	  ,Status			NVARCHAR(10)
	  ,transdate		DATETIME
	  ,betid			BIGINT
	  ,Transdesc		NVARCHAR(1000)
	  ,statusID			TINYINT
	  ,srecommend		INT
	  ,mrecommend		INT
	  ,recommend		INT
	  ,creator			INT
	  ,WalletType		TINYINT
	  ,RefCode			BIGINT
	  ,stake			MONEY
	  ,oddstype			TINYINT
	  ,CurrencyName		NVARCHAR(50)
	  ,betdaqid			BIGINT
	  ,ExtraInfo		VARCHAR(1000)
	  ,statuswinlost	TINYINT
	  ,IsMoved14		BIT
	  ,winlost			MONEY
	  ,actual_stake		MONEY
	  ,winlostdate		SMALLDATETIME
	  ,modds			SMALLMONEY
	  ,IsMixParlay		BIT
	  ,SiteDBGroupID	SMALLINT
	  ,username         NVARCHAR(50)
	  ,homeid           INT
      ,awayid           INT
	  ,leagueid         INT
	  ,isNeutral        BIT
	  ,matchcode        NVARCHAR(50)
	  ,showtime         NVARCHAR(50)
      ,sporttype        SMALLINT
	  ,eventstatus		NVARCHAR(50)
	  ,CustomerClass	SMALLINT
	  ,IsVipMember		BIT DEFAULT(0)
	)
	INSERT INTO #tmpTransInfo( 
		   matchid, transid, refno, custid, hdp1, hdp2, livehomescore, liveawayscore, liveindicator, odds, oddsspread 
		 , betfrom, bettype, betteam, betcheck, Status, transdate, betid, Transdesc, statusID
		 , srecommend, mrecommend, recommend, creator, WalletType, RefCode, stake, oddstype, winlost
		 , CurrencyName, betdaqid, ExtraInfo, actual_stake, winlostdate, modds, statuswinlost, IsMoved14, IsMixParlay, SiteDBGroupID
		)
	SELECT mid, t, ref, c, hdp1, hdp2, lh, la, li, o, os
		 , bfr, btype, bteam, bcheck, s, tdate, bid, tdes, sid 
		 , sre, mre, re, cr, wt, refc, stake, ost, w
		 , curr, bdaq, ex, acstake, wld, m, statuswl, isM, isP, sitedb
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
			SELECT mid, t, ref, c, hdp1, hdp2, lh, la, li, o, os
				 , bfr, btype, bteam, bcheck, s, tdate, bid, tdes, sid 
				 , sre, mre, re, cr, wt, refc, stake, ost, w
				 , curr, bdaq, ex, acstake, wld, m, statuswl, isM, isP, sitedb
				FROM OPENJSON(t.Decompress_TransInfoJson) 
				WITH( mid INT, t BIGINT, ref BIGINT, c INT, hdp1 SMALLMONEY, hdp2 SMALLMONEY, lh SMALLINT, la SMALLINT, li BIT, o SMALLMONEY, os MONEY
					, bfr NVARCHAR(4), btype SMALLINT ,bteam NVARCHAR(10) ,bcheck NVARCHAR(50), s NVARCHAR(10), tdate DATETIME,bid BIGINT ,tdes NVARCHAR(1000), sid TINYINT 
					, sre INT, mre INT, re INT, cr INT, wt TINYINT, refc BIGINT, stake MONEY, ost TINYINT, w MONEY
					, curr NVARCHAR(50), bdaq BIGINT, ex VARCHAR(1000), acstake MONEY, wld SMALLDATETIME, m SMALLMONEY ,statuswl TINYINT ,isM BIT ,isP BIT ,sitedb SMALLINT
				)
		) tbl
	WHERE f.value <> ''

	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransInfo WHERE bettype NOT IN (9, 29, 2799) AND IsMoved14 = 0))
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
		FROM #tmpTransInfo d
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29, 2799)
	END
	
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTransInfo WHERE bettype NOT IN (9, 29, 2799) AND IsMoved14 = 1))
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
		FROM #tmpTransInfo d
			INNER JOIN dbo.match14 m WITH (NOLOCK) 
			ON	d.matchid = m.matchid
		WHERE d.bettype NOT IN (9, 29, 2799)
	END

	UPDATE al
		SET username = ci.username
		   ,CustomerClass = CASE WHEN ci.CustomerClass IN (201, 4000) THEN ci.CustomerClass ELSE NULL END 
		   ,IsVipMember = CASE WHEN vip.CustID IS NOT NULL THEN 1 ELSE 0 END
	FROM	#tmpTransInfo al
		INNER JOIN CustDB.dbo.custInfo ci WITH(NOLOCK)
			ON al.custid = ci.custid
		LEFT JOIN @VIPAccount_tmp vip ON al.custid = vip.CustID

	INSERT INTO #DuplicatedTransids (transid)
	SELECT i.transid
	FROM #tmpInputTransid_RemarkId i
		INNER JOIN #tmpTransInfo t ON i.Transid = t.transid
	GROUP BY i.transid
	HAVING COUNT(1) >= 2

	UPDATE t
	SET t.RemarkId = 2
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #DuplicatedTransids u ON t.Transid = u.transid

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo)
	BEGIN
		--1. Info match table
		SELECT MatchId FROM @tmpMatchId
		
		--2. Validate Table
		SET @InvalidTransIds = @TransIds
		SELECT @InvalidTransIds AS InvalidTransIds

		--3. List ticket unmark (if any)
		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId

		--4. Transinfo table
		SELECT @TransInfoJson_Output AS TransInfoJson

		--5. Export Ticket that the user inputs table
		SELECT TransId, 1 AS RemarkId  FROM #tmpInputTransid_RemarkId

		RETURN;
	END

	IF @FilterBy IS NULL
	BEGIN
		SET @MatchId = (SELECT TOP 1 b.matchid
							FROM #tmpTransInfo AS b WITH (NOLOCK)
								INNER JOIN #inputTransid tmp ON b.transid = tmp.transid
							WHERE (1= CASE WHEN @ActionId <> 2 AND b.statusID NOT IN (101, 102) THEN 1
										   WHEN @ActionId = 2 AND b.statusID  <> 101 THEN 1
										   ELSE 0 END) 
									AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype)
									AND b.matchcode IS NOT NULL 			
									)
		IF @MatchId IS NULL
		BEGIN
			--1. Info match table
			SELECT MatchId FROM @tmpMatchId
		
			--2. Validate Table
			SET @InvalidTransIds = @TransIds
			SELECT @InvalidTransIds AS InvalidTransIds

			--3. List ticket unmark (if any)
			SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId

			--4. Transinfo table
			SELECT @TransInfoJson_Output AS TransInfoJson

			--5. Export Ticket that the user inputs table
			SELECT  t.transid 
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
					,CASE WHEN t.RemarkId IS NOT NULL THEN t.RemarkId ELSE 1 END
					,s.IsVipMember
					,s.CustomerClass
				FROM #tmpInputTransid_RemarkId t
					LEFT JOIN #tmpTransInfo s ON t.transid = s.transid
			
			RETURN;
		END

		INSERT INTO @tmpMatchId (MatchId, homeid, awayid, leagueid,sporttype, matchcode)
		SELECT m.matchid, homeid, awayid, leagueid, sporttype, matchcode
		FROM dbo.match m WITH(NOLOCK) 
		WHERE matchid = @MatchId
	END
	ELSE IF @FilterBy =1
	BEGIN
		SET @MatchId = 29
		INSERT INTO @tmpMatchId (MatchId)
		SELECT @MatchId
	END
	 
	-- select valid TransId of Abnormal bet
	INSERT INTO #validTransId (
		transid
		,isInMatch
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
		)
	SELECT b.transid
		,CASE WHEN b.matchid = @MatchId THEN 1 ELSE 0 END
		,b.statusID
		,b.bettype
		,b.custid
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,m.matchid
		,m.sporttype
		,b.betfrom
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,b.betteam
		,CurrencyName
		,b.IsVipMember
		,b.CustomerClass
	FROM #tmpTransInfo b
		INNER JOIN #inputTransid tmp ON b.transid = tmp.transid
		LEFT JOIN @tmpMatchId m ON b.matchid = b.matchid
	WHERE 1 = CASE WHEN @FilterBy IS NULL AND b.bettype <> 29 THEN 1
			       WHEN @FilterBy = 1 AND b.bettype = 29 THEN 1
				   ELSE 0 END
		AND b.IsMoved14 = 0

	-- get unsuppored transid
	INSERT #UnsupportedTransids (transid)
	SELECT t.transid
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE 1 = CASE WHEN bt.bettype IS NULL 
						AND (t.bettype <> 29 OR (t.bettype = 29  AND t.betteam <> '1')) --Unsupported System parlay Transids
				   THEN 1
				   ELSE 0 END

	SELECT @UnsupportedTransids = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #UnsupportedTransids t
									FOR XML PATH('')), 1, 1, ''), '')
	
	UPDATE t
	SET t.RemarkId = 5
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #UnsupportedTransids u ON t.Transid = u.transid

	-- get ABWhiteList Cust
	INSERT INTO @CustId_tmp (CustID, recommend, mrecommend, srecommend)
	SELECT DISTINCT v.custId, v.recommend, v.mrecommend, v.srecommend
	FROM #validTransId v
	
	INSERT #ABWhiteListCustIds (custid, AllowVoidSubType, IsAllowVoidVip)
	SELECT t.custId, ab.AllowVoidSubType, ab.IsAllowVoidVip 
	FROM @CustId_tmp t
		CROSS APPLY (
					SELECT TOP(1) a.AllowVoidSubType, a.IsAllowVoidVip					
					FROM dbo.TicketVoiding_ABWhiteList a WITH (NOLOCK)	
					WHERE a.CustID IN (t.CustID, t.recommend, t.mrecommend, t.srecommend)
					ORDER BY a.LevelId
			)ab
	
	--final valid transid
	DELETE t
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE (1 = CASE WHEN @ActionId <>2 AND StatusId IN (101, 102, 103) THEN 1
				    WHEN @ActionId = 2 AND StatusId IN (101, 103) THEN 1
					ELSE 0 END)
		OR (bt.bettype IS NULL AND 1 = CASE WHEN @FilterBy IS NULL THEN 1 
										    WHEN @FilterBy = 1 AND t.bettype = 29  AND t.betteam <> '1' THEN 1
										    ELSE 0 END 
										   )
		OR t.betfrom ='p'
	
	INSERT INTO #TransidInRequest (TransId)
	SELECT DISTINCT tmp.transid
	FROM dbo.TicketVoiding_Request req WITH (NOLOCK)
		CROSS APPLY (
					SELECT TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
					WHERE RequestId = req.RequestId AND (MatchId = @MatchId OR MatchId = 29)
				) AS tmp
	WHERE  req.RequestId <> @RequestId AND req.ActionId <> 2

	-- get invalid or moved transId
	INSERT INTO #invalidTransId (transid, isMoved)
	SELECT temp.transid
		  ,ISNULL(bm.IsMoved14, 0) AS isMoved
	FROM #inputTransid AS temp
		OUTER APPLY (
		SELECT TOP 1 IsMoved14
		FROM #tmpTransInfo
		WHERE transid = temp.transid AND IsMoved14 = 1
		) bm
		OUTER APPLY (
		SELECT transid
		FROM #UnsupportedTransids
		WHERE transid = temp.transid
		) u
	WHERE NOT EXISTS (SELECT 1 FROM #validTransId WHERE transid = temp.transid )
		AND u.transid IS NULL

	SELECT @InvalidTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
									FROM #invalidTransId
									WHERE isMoved = 0
									FOR XML PATH('')), 1, 1, ''), '')

	SELECT @MovedTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50))
								FROM #invalidTransId
								WHERE isMoved = 1
								FOR XML PATH('')), 1, 1, ''), '')

	UPDATE t
	SET t.RemarkId = CASE WHEN v.isMoved = 0 THEN 1 ELSE 2 END
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #invalidTransId v ON t.Transid = v.transid
	
	SELECT @DifferentMatchTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
										FROM #validTransId AS v
										WHERE v.isInMatch = 0 AND @MatchId NOT IN (0,29)
										FOR XML PATH('')), 1, 1, ''), '')

	UPDATE t
	SET t.RemarkId = 3
	FROM #tmpInputTransid_RemarkId t
		INNER JOIN #validTransId v ON t.Transid = v.transid
	WHERE v.isInMatch = 0 AND @MatchId NOT IN (0,29)

	SET @IsHasUUSTickets = ISNULL((SELECT TOP 1 1 FROM #validTransId WHERE CurrencyName = 'UUS'),0)

	SET @ListBettype = ISNULL(STUFF((SELECT DISTINCT ', ' + CAST(b.typenamee AS VARCHAR(100))
										FROM #validTransId AS v
										INNER JOIN dbo.bettype b WITH(NOLOCK) ON v.bettype = b.typeid
										WHERE v.bettype <> 29
										FOR XML PATH('')), 1, 1, ''), '')

	SET @ListBetteam = ISNULL(STUFF((SELECT DISTINCT ', ' + CAST(v.betteam AS VARCHAR(100))
										FROM #validTransId AS v
										WHERE v.bettype <> 29
										FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 2, ''), '')
	
	IF @ActionId <> 2
	BEGIN
		SELECT @SettledTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
										FROM #validTransId AS v
										WHERE v.StatusId NOT IN (0,1)
										FOR XML PATH('')), 1, 1, ''), '')
		
		UPDATE t
		SET t.RemarkId = 4 --Settled
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

		--Check AB White List Invalid Transid
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
	
	IF @FilterBy IS NULL AND @ActionId IN (4,6,7) -- Auto Void All (Instant), Auto Void All (5m before KO), Auto Void All (10m before KO)
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
							WHERE matchid = @MatchId
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

	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		INSERT INTO @tmpMarkTransId (TransId, CustID)
		SELECT transid, custId
		FROM #validTransId WHERE StatusId IN (0,1)

		DELETE v
		FROM @tmpMarkTransId v
			LEFT JOIN CustDB.dbo.Custinfo AS c1 WITH (NOLOCK) ON v.custId = c1.custid AND c1.CustomerClass = 201
			LEFT JOIN CustDB.dbo.Custinfo AS c2 WITH (NOLOCK) ON v.custId = c2.custid AND c2.CustomerClass = 4000
		WHERE 1 = CASE WHEN @IsRemoveCustomerClass201 = 1 AND c1.custid IS NOT NULL THEN 1
					   WHEN @IsRemoveCustomerClass4K = 1 AND c2.custid IS NOT NULL THEN 1
					ELSE 0 END
		
	END
	ELSE IF @RequestId <> 0
	BEGIN
		SELECT @OldActionId = ISNULL(ActionId,0) FROM dbo.TicketVoiding_Request WITH(NOLOCK) WHERE RequestId = @RequestId

		IF @ActionId <> 2 AND @OldActionId <> 2
		BEGIN
			--Remove transid from request => unmark ticket & re-cal ticket
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT transid 
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
			WHERE NOT EXISTS( SELECT TOP 1 1 FROM #validTransId it WHERE rdt.TransId=it.transid) -- exist vs input
					AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
					AND rdt.RequestId = @RequestId
	
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT v.transid 
			FROM #validTransId v
				LEFT JOIN CustDB.dbo.Custinfo AS c1 WITH (NOLOCK) ON v.custId = c1.custid AND c1.CustomerClass = 201
				LEFT JOIN CustDB.dbo.Custinfo AS c2 WITH (NOLOCK) ON v.custId = c2.custid AND c2.CustomerClass = 4000
			WHERE 1 = CASE WHEN @IsRemoveCustomerClass201 = 1 AND c1.custid IS NOT NULL THEN 1
						   WHEN @IsRemoveCustomerClass4K = 1 AND c2.custid IS NOT NULL THEN 1
					      ELSE 0 END
			
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
			INSERT INTO @tmpMarkTransId (TransId, CustID)
			SELECT transid, custId
			FROM #validTransId WHERE StatusId IN (0,1)

			DELETE v
			FROM @tmpMarkTransId v
				LEFT JOIN CustDB.dbo.Custinfo AS c1 WITH (NOLOCK) ON v.custId = c1.custid AND c1.CustomerClass = 201
				LEFT JOIN CustDB.dbo.Custinfo AS c2 WITH (NOLOCK) ON v.custId = c2.custid AND c2.CustomerClass = 4000
			WHERE 1 = CASE WHEN @IsRemoveCustomerClass201 = 1 AND c1.custid IS NOT NULL THEN 1
						   WHEN @IsRemoveCustomerClass4K = 1 AND c2.custid IS NOT NULL THEN 1
						ELSE 0 END

		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId --Take note
		BEGIN
			INSERT INTO @tmpUnmarkTransId (TransId)
			SELECT rdt.TransId
			FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
			WHERE rdt.RequestId = @RequestId
			
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
	SELECT matchid, homeid, awayid, leagueid, sporttype, matchcode
	FROM @tmpMatchId
		
	--2. Validate Table
	SELECT   @MovedTransIds AS MovedTransIds
			,@DifferentMatchTransIds AS DifferentMatchTransIds
			,@InvalidTransIds AS InvalidTransIds
			,@SettledTransIds AS SettledTransIds
			,@ExistingReqTransIds AS ExistingReqTransIds
			,@UnsupportedTransids AS UnsupportedTransids
			,@TransIdsOfVIPCustomer AS TransIdsOfVIPCustomer
			,@NonLiveTransIds AS NonLiveTransIds
			,@DifferentLiveScoreTransIds AS DifferentLiveScoreTransIds
			,@TransIdsOfCustomerClass201 AS TransIdsOfCustomerClass201
			,@TransIdsOfCustomerClass4K AS TransIdsOfCustomerClass4K
			,@ABWhiteListTransIds AS ABWhiteListTransIds
			,@IsHasWarningRemovedTickets AS IsHasWarningRemovedTickets
			,@IsHasUUSTickets AS IsHasUUSTickets
			,@ListBettype AS ListBettype
			,@ListBetteam AS ListBetteam

	--3. List ticket unmark (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@RemoveTransids AS RemoveTransids -- Ticket remove -> re-cal
		  ,@MarkTransIds AS MarkTransIds

	--4. Transinfo table
	SET @TransInfoJson_Output = COMPRESS((SELECT t.matchid AS 'mid'
		,t.transid AS 't'
		,b.custid AS  'c'           
		,b.bettype AS 'btype'
		,b.betteam AS 'bteam'
		,b.betid AS 'bid'
		,b.IsMixParlay AS 'isP'
		,b.SiteDBGroupID AS 'sitedb'
	FROM #validTransId t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid
	FOR JSON PATH))
	
	SELECT CONVERT(VARCHAR(MAX), @TransInfoJson_Output, 1) AS TransInfoJson
	
	--5. Export Ticket that the user inputs table [#194133]
	SELECT  t.transid 
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
		,t.RemarkId 
		,s.IsVipMember
		,s.CustomerClass
	FROM #tmpInputTransid_RemarkId t
		LEFT JOIN #tmpTransInfo s ON t.transid = s.transid

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
	DROP TABLE #DuplicatedTransids
END
