/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Request_CheckAbnormalBet]
(
	 @MatchId	BIGINT = 0
	,@TransIds	VARCHAR(MAX) = NULL
	,@RequestId INT = 0
	,@ActionId	TINYINT	= 0
	,@FilterBy	TINYINT	= NULL
	,@SubIssueTypeId TINYINT	= NULL
	,@IssueTypeId	TINYINT	= NULL
)
AS
/*  
	Created by: Raymond.Le  
	Date: 20190625
	Task: Validate matchId, betId of Abnormal bet
	DB: DBTXN/bodb02   
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
			,@IsCalQueue				 BIT = 0
			,@ResettleTransids			 VARCHAR(MAX) = ''
			,@IsCheckAutoCal			 BIT=0
			,@IsHasWarningRemovedTickets BIT=0
			,@OldAction					 TINYINT
			,@IsExistSingle				 BIT = 0
			,@IsExistParlay				 BIT = 0
			,@IsExistFM					 BIT = 0
			,@IsExistFM2				 BIT = 0
			,@MatchProcessXML			 XML = NULL
			,@TransIdsOfCustomerClass1	 VARCHAR(MAX) = ''
			,@ABWhiteListTransIds		 VARCHAR(MAX) = ''
			,@MatchParlayProcessXML	     XML = NULL
			,@TotalRefnoParlay		     INT = 0
			,@ThreadHold			     INT = 0 -- over threadhold, the parlay process will be locked in systemsetting	

	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)
	DECLARE @tblMatchParlay AS TABLE (MatchId INT, RefNo BIGINT)
	DECLARE @tblMatch AS TABLE (MatchId INT)
	DECLARE @tblRemoveTickets AS TABLE (TransId BIGINT)
	DECLARE @CustId_tmp AS TABLE (CustID INT, recommend INT, mrecommend INT, srecommend INT)
				
	INSERT INTO @bettype_tmp (bettype)
	SELECT DISTINCT pt.bettype
	FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
	WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

	-- check valid match id
	IF @FilterBy IS NULL AND @MatchId <> 0 AND NOT EXISTS (SELECT TOP 1 1
					FROM dbo.match AS m WITH (NOLOCK)
					WHERE m.matchid = @MatchId
						AND EXISTS (
							SELECT TOP 1 1
							FROM dbo.SportBettypeMatrix AS bm WITH (NOLOCK)
								INNER JOIN dbo.Sports AS s WITH (NOLOCK) ON s.SportType = bm.sporttype
							WHERE bm.ProductID = 1
								AND s.SportType = m.sporttype
							)
					)	
	BEGIN
		SELECT @InvalidMatchId = @MatchId

		SELECT @InvalidMatchId AS InvalidMatchId
			,@InvalidTransIds AS InvalidTransIds
			,@MovedTransIds AS MovedTransIds
			,@DifferentMatchTransIds AS DifferentMatchTransIds
			,@SettledTransIds AS SettledTransIds
			,@ExistingReqTransIds AS ExistingReqTransIds
			,@UnsupportedTransids AS UnsupportedTransids
			,@TransIdsOfVIPCustomer AS TransIdsOfVIPCustomer
			,@CN88TransIds AS CN88TransIds
			,@NonLiveTransIds AS NonLiveTransIds
			,@DifferentLiveScoreTransIds AS DifferentLiveScoreTransIds
			,@TransIdsOfCustomerClass1 AS TransIdsOfCustomerClass1
			,@ABWhiteListTransIds AS ABWhiteListTransIds
			,@MatchParlayProcessXML AS MatchParlayProcessXML

		RETURN;
	END
	
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	CREATE TABLE #transid_tmp (transid BIGINT,StatusId INT, statuswinlost TINYINT, refno BIGINT)
	CREATE TABLE #transidremove_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT, refno BIGINT)
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
		,betfrom		NVARCHAR(1)
		,recommend		INT
		,mrecommend		INT
		,srecommend		INT
		,refno			BIGINT
		,betteam		NVARCHAR(10)
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
	
	IF (@TransIds IS NULL
		OR LEN(@TransIds) = 0
			) RETURN;

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	-- Check auto calculator
    SELECT @OldAction = r.ActionId 
	FROM dbo.TicketVoiding_Request r WITH(NOLOCK) 
	WHERE r.RequestId = @RequestId

	IF (@ActionId <> @OldAction AND @ActionId = 2 AND @OldAction IS NOT NULL)
	BEGIN
		INSERT INTO #transid_tmp (transid, StatusId, statuswinlost, refno)
		SELECT t.transid, b.statusID, b.statuswinlost, b.refno
		FROM #transIdTemp t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
		WHERE b.statusID IN (0, 1) --if status of ticket is running
	
		IF @FilterBy = 1
		BEGIN
			INSERT INTO @tblMatch (MatchId)
			SELECT DISTINCT m.matchid
			FROM #transid_tmp tmp
			INNER JOIN dbo.bettransm m WITH(NOLOCK) ON tmp.refno = m.refno
		END
		SET @IsCalQueue = ( SELECT TOP (1) 1
								FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
								WHERE StatusId IN (1,2,4) AND RequestId = 0
								AND 1 = CASE WHEN @FilterBy IS NULL AND matchid = @MatchId THEN 1
											 WHEN @FilterBy = 1 AND matchid IN ( SELECT MatchId FROM @tblMatch) THEN 1
											 ELSE 0 END
							)
		SELECT @ResettleTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
												FROM #transid_tmp
												WHERE statuswinlost IS NOT NULL
												FOR XML PATH('')
									), 1,1,'')
		IF (@ResettleTransids <>'' AND @IsCalQueue =1 )
		BEGIN
			SELECT @IsCheckAutoCal = 1 	-- auto calculator
		END
	END

	INSERT INTO #TransidInRequest (TransId)
	SELECT DISTINCT tmp.transid
	FROM dbo.TicketVoiding_Request req WITH (NOLOCK)
		CROSS APPLY (
					SELECT TransId
					FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
					WHERE RequestId = req.RequestId AND MatchId = @MatchId
				) AS tmp
	WHERE  req.RequestId <> @RequestId AND req.ActionId <>2

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
		)
	SELECT b.transid
		,CASE 
			WHEN b.matchid = @MatchId THEN 1
			ELSE 0
			END
		,b.statusID
		,b.bettype
		,b.custid
		,b.livehomescore
		,b.liveawayscore
		,b.liveindicator
		,@MatchId
		,m.sporttype
		,b.betfrom
		,b.recommend
		,b.mrecommend
		,b.srecommend
		,b.refno
		,b.betteam
	FROM dbo.bettrans AS b WITH (NOLOCK)
		INNER JOIN #transIdTemp tmp ON b.transid = tmp.transid
		LEFT JOIN dbo.match m WITH (NOLOCK) ON m.matchid = b.matchid
	WHERE 1 = CASE WHEN @FilterBy IS NULL THEN 1
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
			INNER JOIN dbo.bettransm b WITH(NOLOCK) ON t.refno = b.refno
			INNER JOIN dbo.match m WITH(NOLOCK) ON b.matchid = m.matchid
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
		
	IF @RequestId <> 0
	BEGIN
		INSERT INTO @tblRemoveTickets (TransId)
		SELECT transid
		FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
		WHERE NOT EXISTS( SELECT TOP 1 1 FROM #validTransId it WHERE rdt.TransId=it.transid) -- exist vs input
				AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
				AND EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = rdt.transid)
				AND rdt.RequestId = @RequestId

		IF @@ROWCOUNT > 0
		BEGIN
			SET @IsHasWarningRemovedTickets = 1
							
			INSERT INTO #transidremove_tmp (transid, bettype, StatusId, statuswinlost, refno)
			SELECT  t.TransId, b.bettype, b.statusID, b.statuswinlost, b.refno
			FROM @tblRemoveTickets t
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.TransId = b.transid
			WHERE b.statusID IN (0,1) AND statuswinlost IS NOT NULL

			IF @@ROWCOUNT > 0 -- ticket have statuswinlost
				SET @IsCheckAutoCal = 1	
		END
	END

	-- invalid transId
	;WITH t_invalid
	AS (
		SELECT temp.transid
			,ISNULL(bm.isMoved, CAST(0 AS BIT)) AS isMoved
			
		FROM #transIdTemp AS temp
			OUTER APPLY (
			SELECT TOP 1 CAST(1 AS BIT) AS isMoved
			FROM dbo.bettrans14 WITH (NOLOCK)
			WHERE transid = temp.transid
			) bm
			OUTER APPLY (
			SELECT transid
			FROM #UnsupportedTransids
			WHERE transid = temp.transid
			) u
		WHERE NOT EXISTS (
				SELECT 1
				FROM #validTransId
				WHERE transid = TEMP.transid
				)
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

	SELECT @DifferentMatchTransIds = ISNULL(STUFF((
				SELECT ',' + CAST(v.transid AS VARCHAR(50))
				FROM #validTransId AS v
				WHERE v.isInMatch = 0 AND @MatchId NOT IN (0,29)
				FOR XML PATH('')
				), 1, 1, ''), '')

	IF @ActionId <> 2
	BEGIN
		SELECT @ExistingReqTransIds = ISNULL(STUFF((SELECT ',' + CAST(t.transid AS VARCHAR(50))
										FROM #transIdTemp t 
											INNER JOIN #TransidInRequest tr ON t.transid = tr.TransId
										FOR XML PATH('')
								), 1, 1, ''), '')

		SELECT @SettledTransIds = ISNULL(STUFF((
					SELECT ',' + CAST(v.transid AS VARCHAR(50))
					FROM #validTransId AS v
					WHERE v.StatusId NOT IN (0,1)
					FOR XML PATH('')
					), 1, 1, ''), '')

		--get list VIP Account
		SELECT  @query = N''		
		SELECT	@query = @query + N'SELECT Custid 
									FROM dbo.Dep_CustVIP WITH (NOLOCK)	
									'
		SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
		INSERT INTO @VIPAccount_tmp(CustID)
		EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

		SELECT @TransIdsOfVIPCustomer = ISNULL(STUFF((
					SELECT ', ' + CAST(v.transid AS VARCHAR(50))
					FROM #validTransId AS v				
					WHERE EXISTS (
						SELECT TOP 1 1
						FROM @VIPAccount_tmp as vip
						WHERE vip.CustID = v.custId
					)
					FOR XML PATH('')
					), 1, 1, ''), '')

		-- Check validation for the ticket that has customer class = 1
		SELECT @TransIdsOfCustomerClass1 = ISNULL(STUFF((
					SELECT ',' + CAST(v.transid AS VARCHAR(50))
					FROM #validTransId AS v	
						INNER JOIN CustDB.dbo.Custinfo AS c WITH (NOLOCK) ON v.custId = c.custid
					WHERE c.CustomerClass = 1
					FOR XML PATH('')
					), 1, 1, ''), '')

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
										FOR XML PATH('')
								), 1, 1, ''), '')
		END
	END
	
	IF @ActionId IN (4,6,7) -- Auto Void All (Instant), Auto Void All (5m before KO), Auto Void All (10m before KO)
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
							WHERE @MatchId = matchid
						) m

		SELECT @NonLiveTransIds = ISNULL(STUFF((SELECT ',' + CAST(lt.transid AS VARCHAR(50))
										FROM #LiveTransIds lt
										WHERE lt.IsNonLive = 1
										FOR XML PATH('')
								), 1, 1, ''), '')

		SELECT @DifferentLiveScoreTransIds = ISNULL(STUFF((SELECT ',' + CAST(lt.transid AS VARCHAR(50))
										FROM #LiveTransIds lt
										WHERE lt.IsDifferentScore = 1
										FOR XML PATH('')
								), 1, 1, ''), '')

		-- get cn88 tickets
		SELECT @CN88TransIds = ISNULL(STUFF((
					SELECT ', ' + CAST(v.transid AS VARCHAR(50))
					FROM #validTransId AS v				
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.transid = v.transid
						LEFT JOIN dbo.CS_CustSuper cs WITH (NOLOCK) ON b.srecommend = cs.CustId
					WHERE cs.CustId IS NOT NULL
					FOR XML PATH('')
					), 1, 1, ''), '')
	END

	---Prepare for lock match---
	SELECT @IsExistSingle = MAX(CASE WHEN t.Bettype NOT IN (9, 29, 10, 801, 803, 804, 805, 806) AND f.GroupId IS NULL THEN 1 ELSE 0 END)
			,@IsExistFM = MAX(CASE WHEN f.GroupId = 1 THEN 1 ELSE 0 END)
			,@IsExistFM2 = MAX(CASE WHEN f.GroupId = 2 THEN 1 ELSE 0 END)
			,@IsExistParlay = MAX(CASE WHEN t.Bettype IN (9, 29) AND f.GroupId IS NULL THEN 1 ELSE 0 END)

	FROM #validTransId AS t
		OUTER APPLY (
				SELECT GroupId
				FROM dbo.f_TVS_CheckingProcessGroupBettypes()
				WHERE Bettype = t.Bettype
		)f

	IF @FilterBy IS NULL
	BEGIN
		SET @MatchProcessXML = (
			SELECT DISTINCT MatchId "@MatchId"
				,CASE 
					WHEN f.GroupId IS NULL THEN 1 --SB
					WHEN f.GroupId = 1 THEN 6 -- Fast Market
					WHEN f.GroupId = 2 THEN 7 -- Fast market 228
					ELSE 0
					END AS "@KeyID" 
			FROM #validTransId t
				OUTER APPLY (
						SELECT GroupId
						FROM dbo.f_TVS_CheckingProcessGroupBettypes()
						WHERE Bettype = t.Bettype
				)f
			FOR XML PATH('r'), ROOT('root')
			)
	END

	IF @FilterBy = 1 --Mixparlay ticket
	BEGIN
		--Lock Refno process - SportBook
		EXEC dbo.NAP_Set_GlobalSettingSel 
			@LockName = 'ParlayRefno'
			,@ThreadHold = @ThreadHold OUTPUT

		INSERT INTO @tblMatchParlay (MatchId, RefNo)
		SELECT DISTINCT MatchId, refno
		FROM #validTransId 
		SET @TotalRefnoParlay = @@ROWCOUNT

		IF @TotalRefnoParlay <= @ThreadHold
		BEGIN
			SET @MatchParlayProcessXML = (
			SELECT  MatchId "@MatchId"
					,refno AS "@RefNo"
			FROM @tblMatchParlay 
			FOR XML PATH('r'), ROOT('root'))
		END	
		ELSE
		BEGIN
			SET @MatchParlayProcessXML = NULL
		END
	END
	-- return table result
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
			,@IsCheckAutoCal AS IsCheckAutoCal
			,@IsHasWarningRemovedTickets AS IsHasWarningRemovedTickets
			,@IsExistSingle AS IsExistSingle
			,@IsExistParlay AS IsExistParlay
			,@IsExistFM AS IsExistFM
			,@IsExistFM2 AS IsExistFM2
			,@MatchProcessXML AS MatchProcessXML
			,@MatchParlayProcessXML AS MatchParlayProcessXML

	DROP TABLE #transIdTemp
	DROP TABLE #transid_tmp
	DROP TABLE #validTransId
	DROP TABLE #TransidInRequest
	DROP TABLE #UnsupportedTransids
	DROP TABLE #LiveTransIds
	DROP TABLE #ABWhiteListTransIds
	DROP TABLE #transidremove_tmp
	DROP TABLE #ABWhiteListCustIds
	DROP TABLE #ABWhiteListCustIds_AllowVoid
END
