/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_CheckAbnormalBet]
(
	 @TransIds	VARCHAR(MAX) = NULL
	,@RequestId INT = 0
	,@ActionId	TINYINT	= 0
	,@FilterBy	TINYINT	= NULL
	,@SubIssueTypeId TINYINT	= NULL
	,@TransInfo	XML = NULL
	,@IsRemoveCustomerClass1 BIT = 0
)
AS
/*  
	Created by: Raymond.Le  
	Date: 20190625
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

	Param's Explanation:
		+ @MatchId: MatchId of current @TransIds
		+ @TransIds: Search by TransID
*/
BEGIN
	SET NOCOUNT ON;

	DECLARE @InvalidTransIds			 VARCHAR(MAX) = ''
			,@MovedTransIds				 VARCHAR(MAX) = ''
			,@DifferentMatchTransIds     VARCHAR(MAX) = '' 
			,@InvalidMatchId		     VARCHAR(200) = ''
			,@SettledTransIds			 VARCHAR(MAX) = ''
			,@UnsupportedTransids		 VARCHAR(MAX) = ''
			,@ExistingReqTransIds		 VARCHAR(MAX) = ''
			,@TransIdsOfVIPCustomer		 VARCHAR(MAX) = ''
			,@CN88TransIds				 VARCHAR(MAX) = ''
			,@NonLiveTransIds			 VARCHAR(MAX) = ''
			,@DifferentLiveScoreTransIds VARCHAR(MAX) = ''
			,@query						 NVARCHAR(MAX) = ''
			,@ExecuteSQL				 NVARCHAR(MAX) = ''
			,@IsHasWarningRemovedTickets BIT=0
			,@IsHasUUSTickets			 BIT=0
			,@OldActionId				 TINYINT
			,@TransIdsOfCustomerClass1	 VARCHAR(MAX) = ''
			,@ABWhiteListTransIds		 VARCHAR(MAX) = ''
			,@MatchId					 INT = 0
			,@MarkTransIds 			     VARCHAR(MAX) =''
			,@UnmarkTransIds 			 VARCHAR(MAX) =''
			,@RemoveTransids 			 VARCHAR(MAX) ='' -- Ticket remove will re-cal (if any)
	
	DECLARE @homeid INT, @awayid INT, @leagueid INT, @sporttype SMALLINT, @matchcode NVARCHAR(50)

	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @CustId_tmp AS TABLE (CustID INT, recommend INT, mrecommend INT, srecommend INT)
	DECLARE @tmpUnmarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMarkTransId AS TABLE (TransId BIGINT)
	DECLARE @tmpMatchId AS TABLE (MatchId INT)

	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	IF (@TransIds IS NULL OR LEN(@TransIds) = 0) RETURN;

	CREATE TABLE #inputTransid (transid BIGINT PRIMARY KEY)
	INSERT INTO #inputTransid (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	CREATE TABLE #transidremove_tmp (transid BIGINT, StatusId INT, statuswinlost TINYINT)
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
		,betfrom		NVARCHAR(3)
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,refno			BIGINT
		,betteam		NVARCHAR(10)
		,SubMatchIdList	VARCHAR(2000)
		,CurrencyName	NVARCHAR(50)
		)
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
	   matchid INT
	  ,transid BIGINT
	  ,custid	INT	
      ,livehomescore SMALLINT
      ,liveawayscore SMALLINT
      ,liveindicator BIT
      ,betteam NVARCHAR(10)
      ,refno BIGINT
      ,bettype SMALLINT
      ,betid BIGINT
	  ,betdaqid BIGINT
      ,statusID TINYINT
      ,betfrom NVARCHAR(3)
	  ,recommend INT
	  ,mrecommend INT
	  ,srecommend INT
	  ,CurrencyName NVARCHAR(50)
	  ,statuswinlost TINYINT
	  ,SubMatchIdList VARCHAR(2000)
	  ,IsMoved14 BIT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,refno
		  ,custid		
		  ,livehomescore 
		  ,liveawayscore 
		  ,liveindicator 
		  ,betteam
		  ,bettype
		  ,betid
		  ,betdaqid 
		  ,betfrom
		  ,statusID
		  ,recommend 
		  ,mrecommend
		  ,srecommend
		  ,CurrencyName
		  ,statuswinlost
		  ,SubMatchIdList
		  ,IsMoved14
		  ,IsMixParlay
		  ,SiteDBGroupID

		)
	SELECT t.c.value('@mid','INT') AS matchid
			,t.c.value('@t','BIGINT') AS transid
			,t.c.value('@ref','BIGINT') AS refno
			,t.c.value('@c','INT') AS custid
			,t.c.value('@lh','SMALLINT') AS livehomescore
			,t.c.value('@la','SMALLINT') AS liveawayscore
			,t.c.value('@li','BIT') AS liveindicator
			,t.c.value('@bteam','NVARCHAR(10)') AS betteam
			,t.c.value('@btype','SMALLINT') AS bettype
			,t.c.value('@bid','BIGINT') AS betid
			,t.c.value('@bdaq','BIGINT') AS betdaqid
			,t.c.value('@bfr','NVARCHAR(3)') AS betfrom
			,t.c.value('@sid','TINYINT') AS statusID
			,t.c.value('@re','INT') AS recommend
			,t.c.value('@mre','INT') AS mrecommend
			,t.c.value('@sre','INT') AS srecommend
			,t.c.value('@curr','NVARCHAR(50)') AS CurrencyName
			,t.c.value('@statuswl','TINYINT') AS statuswinlost
			,t.c.value('@s_mid','VARCHAR(2000)') AS SubMatchIdList
			,t.c.value('@IsM','BIT') AS IsMoved14
			,t.c.value('@isP','BIT') AS IsMixParlay
			,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
	FROM @TransInfo.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

	IF NOT EXISTS (SELECT TOP 1 1 FROM #tmpTransInfo)
	BEGIN
		SELECT MatchId FROM @tmpMatchId

		SET @InvalidTransIds = @TransIds
		SELECT @InvalidTransIds AS InvalidTransIds

		SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId

		SELECT matchid FROM #tmpTransInfo
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
									AND EXISTS (SELECT TOP 1 1 FROM @bettype_tmp bt WHERE bt.bettype = b.bettype))
	
		IF @MatchId IS NULL
		BEGIN
			SELECT MatchId FROM @tmpMatchId

			SET @InvalidTransIds = @TransIds
			SELECT  @InvalidTransIds AS InvalidTransIds

			SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId

			DELETE FROM #tmpTransInfo
			SELECT matchid FROM #tmpTransInfo
			RETURN;
		END
		ELSE
		BEGIN
			-- check valid match id
			IF NOT EXISTS (SELECT TOP 1 1
							FROM dbo.match AS m WITH (NOLOCK)
							WHERE m.matchid = @MatchId
								AND EXISTS (
									SELECT TOP 1 1
									FROM dbo.SportBettypeMatrix AS bm WITH (NOLOCK)
									WHERE bm.ProductID = 1
										AND bm.SportType = m.sporttype
									)
							)	
			BEGIN
				SELECT @MatchId AS MatchId

				SET @InvalidMatchId = @MatchId
				SELECT @InvalidMatchId AS InvalidMatchId

				SELECT TransId AS UnmarkTransIds FROM @tmpUnmarkTransId

				DELETE FROM #tmpTransInfo
				SELECT matchid FROM #tmpTransInfo
				RETURN;
			END
		END
	END

	SELECT @homeid = m.homeid
		  ,@awayid = m.awayid
	      ,@leagueid = m.leagueid
		  ,@sporttype = m.sporttype
	      ,@matchcode = m.matchcode
	FROM dbo.match m WITH(NOLOCK) 
	WHERE m.matchid = @MatchId

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
		,refno
		,betteam
		,SubMatchIdList
		,CurrencyName
		)
	SELECT b.transid
		,CASE WHEN b.matchid = @MatchId THEN 1 ELSE 0 END
		,b.statusID
		,b.bettype
		,b.custid
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,CASE WHEN @FilterBy = 1 THEN 29 ELSE @MatchId END
		,@sporttype
		,b.betfrom
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,b.refno
		,b.betteam
		,SubMatchIdList
		,CurrencyName
	FROM #tmpTransInfo b
		INNER JOIN #inputTransid tmp ON b.transid = tmp.transid
	WHERE 1 = CASE WHEN @FilterBy IS NULL AND b.bettype <> 29 THEN 1
			       WHEN @FilterBy = 1 AND b.bettype = 29 THEN 1
				   ELSE 0 END

	-- get unsuppored transid
	INSERT #UnsupportedTransids (transid)
	SELECT t.transid
	FROM #validTransId t
		OUTER APPLY (SELECT bettype FROM @bettype_tmp WHERE bettype = t.bettype) bt
	WHERE 1 = CASE WHEN ISNULL(t.sporttype,0) <> 50 AND bt.bettype IS NULL 
						AND (t.bettype <> 29 OR (t.bettype = 29  AND t.betteam <> '1')) --Unsupported System parlay Transids
				   THEN 1
				   WHEN  t.sporttype = 50 THEN 1
				   ELSE 0 END

	IF @FilterBy = 1
	BEGIN
		-- Unsupported mixparlay tickets have submatch cricket
		INSERT #UnsupportedTransids (transid)
		SELECT DISTINCT t.transid
		FROM #validTransId t
			CROSS APPLY (
					SELECT value AS submatchId
					FROM STRING_SPLIT (t.SubMatchIdList,',')
			)s
			INNER JOIN dbo.match m WITH(NOLOCK) ON s.submatchId = m.matchid
		WHERE t.bettype = 29 AND t.betteam = '1' AND m.sporttype = 50 
		AND t.transid NOT IN (SELECT transid FROM #UnsupportedTransids)
	END	

	SELECT @UnsupportedTransids = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
									FROM #UnsupportedTransids t
									FOR XML PATH('')
							), 1, 1, ''), '')
	
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


	-- invalid transId
	;WITH t_invalid
	AS (
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
		)
	SELECT @InvalidTransIds = @InvalidTransIds + CASE 
			WHEN isMoved = 0 THEN CASE 
					WHEN @InvalidTransIds <> '' THEN ','
					ELSE ''
					END + CAST(transid AS VARCHAR(100))
			ELSE ''
			END
		,@MovedTransIds = @MovedTransIds + CASE 
			WHEN isMoved = 1 THEN CASE 
					WHEN @MovedTransIds <> '' THEN ','
					ELSE ''
					END + CAST(transid AS VARCHAR(100))
			ELSE ''
			END
	FROM t_invalid

	SELECT @DifferentMatchTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
										FROM #validTransId AS v
										WHERE v.isInMatch = 0 AND @MatchId NOT IN (0,29)
										FOR XML PATH('')), 1, 1, '')
										, '')
	SET @IsHasUUSTickets = ISNULL((SELECT TOP 1 1 FROM #validTransId WHERE CurrencyName = 'UUS'),0)

	IF @ActionId <> 2
	BEGIN
		SELECT @ExistingReqTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #inputTransid t 
											INNER JOIN #TransidInRequest tr ON t.transid = tr.TransId
										FOR XML PATH('')), 1, 1, '')
										, '')

		SELECT @SettledTransIds = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
										FROM #validTransId AS v
										WHERE v.StatusId NOT IN (0,1)
										FOR XML PATH('')), 1, 1, '')
										, '')

		--get list VIP Account
		SELECT  @query = N''		
		SELECT	@query = @query + N'SELECT Custid 
									FROM dbo.Dep_CustVIP WITH (NOLOCK)	
									'
		SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
		INSERT INTO @VIPAccount_tmp(CustID)
		EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

		SELECT @TransIdsOfVIPCustomer = ISNULL(STUFF((SELECT ', ' + CAST(v.transid AS VARCHAR(50))
											FROM #validTransId AS v				
											WHERE EXISTS (
												SELECT TOP 1 1
												FROM @VIPAccount_tmp as vip
												WHERE vip.CustID = v.custId)
											FOR XML PATH('')), 1, 1, '')
											, '')

		-- Check validation for the ticket that has customer class = 1
		SELECT @TransIdsOfCustomerClass1 = ISNULL(STUFF((SELECT ',' + CAST(v.transid AS VARCHAR(50))
												FROM #validTransId AS v	
													INNER JOIN CustDB.dbo.Custinfo AS c WITH (NOLOCK) ON v.custId = c.custid
												WHERE c.CustomerClass = 1
												FOR XML PATH('')), 1, 1, '')
											, '')

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
											FOR XML PATH('')), 1, 1, '')
										  , '')
		END
	END
	
	IF @RequestId = 0 AND @ActionId <> 2
	BEGIN
		IF @TransIdsOfCustomerClass1  <> '' AND @IsRemoveCustomerClass1 = 1
		BEGIN
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT v.transid 
			FROM #validTransId v
				LEFT JOIN CustDB.dbo.Custinfo AS c WITH (NOLOCK) ON v.custId = c.custid AND c.CustomerClass = 1
			WHERE c.custid IS NULL AND v.StatusId IN (0,1)
		END
		ELSE
		BEGIN
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT transid FROM #validTransId WHERE StatusId IN (0,1)
		END

		SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM @tmpMarkTransId
											FOR XML PATH('')), 1,1,'')
											,'')
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

			IF @TransIdsOfCustomerClass1  <> '' AND @IsRemoveCustomerClass1 = 1
			BEGIN
				INSERT INTO @tmpUnmarkTransId (TransId)
				SELECT v.transid 
				FROM #validTransId v
					LEFT JOIN CustDB.dbo.Custinfo AS c WITH (NOLOCK) ON v.custId = c.custid AND c.CustomerClass = 1
				WHERE c.custid IS NOT NULL
			END
			
			--Add mark ticket when edit request (mark all again -> support case unmark by function SD)
			INSERT INTO @tmpMarkTransId (TransId)
			SELECT transid 
			FROM #validTransId v
			WHERE v.StatusId IN (0,1) AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = v.TransId)-- exist in # request
				AND NOT EXISTS ( SELECT TOP 1 1 FROM @tmpUnmarkTransId um WHERE um.TransId = v.transid)

			SELECT @UnmarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
												FROM @tmpUnmarkTransId
												FOR XML PATH('')), 1,1,'')
												,'')

			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
												FROM @tmpMarkTransId
												FOR XML PATH('')), 1,1,'')
												,'')

			IF @UnmarkTransIds <> ''
			BEGIN
				SET @IsHasWarningRemovedTickets = 1
				
				SELECT @RemoveTransids = @UnmarkTransIds
			END
		END
		ELSE IF @ActionId <> 2 AND @OldActionId = 2
		BEGIN
			IF @TransIdsOfCustomerClass1  <> '' AND @IsRemoveCustomerClass1 = 1
			BEGIN
				INSERT INTO @tmpMarkTransId (TransId)
				SELECT v.transid 
				FROM #validTransId v
					LEFT JOIN CustDB.dbo.Custinfo AS c WITH (NOLOCK) ON v.custId = c.custid AND c.CustomerClass = 1
				WHERE c.custid IS NULL AND v.StatusId IN (0,1)
			END
			ELSE
			BEGIN
				INSERT INTO @tmpMarkTransId (TransId)
				SELECT transid FROM #validTransId WHERE StatusId IN (0,1)
			END

			SELECT @MarkTransIds = ISNULL(STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
										FROM @tmpMarkTransId
										FOR XML PATH('')), 1,1,'')
										,'')
		END
		ELSE IF @ActionId = 2 AND @ActionId <> @OldActionId --Take note
		BEGIN
			SELECT @UnmarkTransids = ISNULL(STUFF((SELECT ',' + CAST(rdt.TransId AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE rdt.RequestId = @RequestId
											FOR XML PATH('')), 1,1,'')
											,'')
			
			IF @UnmarkTransIds <> ''
			BEGIN
				SET @IsHasWarningRemovedTickets = 1
				
				SELECT @RemoveTransids = @UnmarkTransIds
			END
		END
	END

	IF @FilterBy IS NULL AND @ActionId IN (4,6,7) -- Auto Void All (Instant), Auto Void All (5m before KO), Auto Void All (10m before KO)
	BEGIN
		-- get non-live and different score transids
		INSERT #LiveTransIds(TransId, IsNonLive, IsDifferentScore)
		SELECT t.transid
			, CASE WHEN m.GlobalShowTime < GETDATE() AND t.liveindicator = 0 THEN 1 ELSE 0 END
			, CASE
				WHEN m.sporttype IN (1,28,49,51) AND t.liveindicator = 1
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
										FOR XML PATH('')), 1, 1, '')
									, '')

		SELECT @DifferentLiveScoreTransIds = ISNULL(STUFF((SELECT ',' + CAST(lt.transid AS VARCHAR(50))
														FROM #LiveTransIds lt
														WHERE lt.IsDifferentScore = 1
														FOR XML PATH('')), 1, 1, '')
											, '')

		-- get cn88 tickets
		SELECT @CN88TransIds = ISNULL(STUFF((SELECT ', ' + CAST(v.transid AS VARCHAR(50))
									FROM #validTransId AS v				
										INNER JOIN #tmpTransInfo b ON b.transid = v.transid AND b.IsMixParlay = 0
										LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.CustId
									WHERE cs.CustId IS NOT NULL
									FOR XML PATH('')), 1, 1, '')
									, '')
	END

	/*****************Return table **************************/
	IF @FilterBy = 1 SET @MatchId = 29
	--1. Info match table
	SELECT  @matchid AS matchid
	, @homeid AS homeid 
	, @awayid AS awayid
	, @leagueid	AS leagueid
	, @sporttype AS sporttype
	, @matchcode AS matchcode
	
	--2. Validate Table
	SELECT @InvalidMatchId AS InvalidMatchId
			,@MovedTransIds AS MovedTransIds
			,@DifferentMatchTransIds AS DifferentMatchTransIds
			,@InvalidTransIds AS InvalidTransIds
			,@SettledTransIds AS SettledTransIds
			,@ExistingReqTransIds AS ExistingReqTransIds
			,@UnsupportedTransids AS UnsupportedTransids
			,@TransIdsOfVIPCustomer AS TransIdsOfVIPCustomer
			,@CN88TransIds AS CN88TransIds
			,@NonLiveTransIds AS NonLiveTransIds
			,@DifferentLiveScoreTransIds AS DifferentLiveScoreTransIds
			,@TransIdsOfCustomerClass1 AS TransIdsOfCustomerClass1
			,@ABWhiteListTransIds AS ABWhiteListTransIds
			,@IsHasWarningRemovedTickets AS IsHasWarningRemovedTickets
			,@IsHasUUSTickets AS IsHasUUSTickets

	--3. List ticket unmark (if any)
	SELECT @UnmarkTransIds AS UnmarkTransIds
		  ,@RemoveTransids AS RemoveTransids -- Ticket remove -> re-cal
		  ,@MarkTransIds AS MarkTransIds

	--4. Transinfo table
	SELECT t.matchid 
		    ,t.transid 
			,b.refno
			,b.custid 
			,b.bettype 
			,t.statusID 
			,b.betteam 
			,b.betid 
			,b.statuswinlost 
			,b.IsMixParlay 
			,b.SiteDBGroupID
			,t.SubMatchIdList
	FROM #validTransId t
		INNER JOIN #tmpTransInfo b ON t.matchid = b.matchid AND t.transid = b.transid

	DROP TABLE #inputTransid
	DROP TABLE #validTransId
	DROP TABLE #TransidInRequest
	DROP TABLE #UnsupportedTransids
	DROP TABLE #LiveTransIds
	DROP TABLE #ABWhiteListTransIds
	DROP TABLE #transidremove_tmp
	DROP TABLE #ABWhiteListCustIds
	DROP TABLE #ABWhiteListCustIds_AllowVoid
	DROP TABLE #tmpTransInfo
END
