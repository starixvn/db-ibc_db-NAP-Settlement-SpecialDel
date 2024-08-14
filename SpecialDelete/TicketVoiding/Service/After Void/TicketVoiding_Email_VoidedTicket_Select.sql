/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_Email_VoidedTicket_Select](
	 @VoidingHistoryId			INT = NULL
	,@IsITSupport				BIT = 0
	,@IsITSupportCreatedRequest BIT = 0
	,@SiteDBGroupID				SMALLINT = 0
	,@IsInsertRoutineTask		BIT = 0
)AS
/*	Created by: 20181212@Kathy
	Task: get voided ticket to send email [Redmine:#90155]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20190812@Charles: Add new column IsMarked [118437]
		- 20191101@Charles: Remove column IsMarked [122187]
		- 20191118@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200216@Max: Abnormal Void Bets Automation [Redmine: #128359]
		- 20200825@July: Change datatype [Redmine: #139914]
		- 20200831@Zane: TVS - Enhance for Danger Accept [#140339]
		- 20201002@Charles: Letstalk notification for void settled bets [141828]
		- 20201127@Charles: God of fortune [Redmine: #146053]
		- 20201214@Charles: TVS - Enhance letstalk notification for settled tickets [Redmine: #145103]
		- 20201204@Charles: Return matchid from result [Redmine: #145719]
		- 20210104@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210226@Max: TVS - SP Time Out [Redmine: #150723]
		- 20210504@July: TVS - Show VIP status on void email (Abnormal bet + AB real member) [Redmine: #153157]
		- 20211207@July: Remove code CashOut [Redmine: #165097]
		- 20220523@July: TVS - Notify Letstalk when void Abnormal Bets [Redmine: #172212]
		- 20220620@July: TVS - Support FT Instant Settlement on HT Calculation [Redmine: #174122]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230517@Max: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20230623@Max: [TVS] Enhance void 14 by Username Feature name [Redmine: #190028]
		- 20230823@Max: [TVS] Instant Settlement of Basketball [Redmine: #185492]
		- 20231213@Max: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240402@July: [TVS] SP tuning for EC2024 [Redmine: #200840]
		- 20240409@July: [TVS] Fix issue duplicate insert voided transaction [Redmine: #203614]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]

	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @query NVARCHAR(MAX) = ''
		   ,@ExecuteSQL NVARCHAR(MAX) = ''

	CREATE TABLE #tmpTicket (
		TransId			BIGINT
		,matchid		INT
		,custid			INT
		,recommend		INT
		,mrecommend		INT
		,Srecommend		INT
		,TransDate		DATETIME
		,Stake			MONEY
		,winlost		MONEY
		,Status			NVARCHAR(10)
		,Betcheck		NVARCHAR(50)
		,betdaqid		BIGINT
		,betid			BIGINT
		,betfrom		NVARCHAR(4)
		,Betteam		NVARCHAR(10)
		,Bettype		SMALLINT
		,Currency		TINYINT
		,CurrencyName	NVARCHAR(50)
		,Hdp1			SMALLMONEY
		,Hdp2			SMALLMONEY
		,LiveHomeScore	SMALLINT
		,LiveAwayScore	SMALLINT
		,Odds			SMALLMONEY
		,Oddsspread		MONEY
		,oddstype		TINYINT
		,BonusId		INT
		,WalletType		TINYINT
		,RefCode		BIGINT
		,ExtraInfo		VARCHAR(1000)
		,TransDesc		NVARCHAR(1000)
		,Username		NVARCHAR(50)
		,IsMixParlay	BIT DEFAULT (0)
		,subbetcheck	NVARCHAR(50)
		,subOdds		SMALLMONEY
		,subbetteam		NVARCHAR(10)
		,subbettype		SMALLINT
		,subhdp1		SMALLMONEY
		,subhdp2		SMALLMONEY
		,subtransdesc	NVARCHAR(1000)
		,SubStatus		NVARCHAR(10)
		,Refno			BIGINT
		,subTransId		BIGINT	
		,VoidedTime		DATETIME
		,MainTransId 	BIGINT
		,IsCashOut		BIT DEFAULT(0)
		,LiveIndicator  BIT
		,ActualStake	MONEY
		,oddsid         INT
		,homeid         INT
        ,awayid         INT
		,leagueid       INT
		,isNeutral      BIT
		,matchcode      NVARCHAR(50)
		,showtime       NVARCHAR(50)
		,SettlementStatus TINYINT
		,sporttype		SMALLINT
		,eventstatus	NVARCHAR(50)
		,IsDeposit      BIT DEFAULT(0) --1: Deposit/ 0: Credit
		,SiteDBGroupID	SMALLINT
		,winlostdate	SMALLDATETIME
		,IsCancelCashOut BIT DEFAULT(0)
		,IsVoidArchived BIT DEFAULT(0)
		,LeagueGroupID  SMALLINT
		,zzzWinlost		MONEY
		,modds			SMALLMONEY
	)
	
	CREATE CLUSTERED INDEX CIX_tmpTicket_transId ON #tmpTicket (TransId)

	CREATE TABLE #InstantSettlementBettypes(matchid INT, bettype SMALLINT, betid BIGINT)	

	-- single ticket
	INSERT INTO #tmpTicket (TransId, matchid, Status, VoidedTime, custid, winlost, Bettype, Refno, Odds, oddsid, SiteDBGroupID, winlostdate, IsCancelCashOut, zzzWinlost)
	SELECT	z.transid			
			,z.matchid
			,z.status
			,z.transdate
			,z.custid
			,z.winlost
			,z.bettype
			,z.refno
			,z.odds
			,z.oddsid
			,z.SiteDBGroupID
			,z.winlostdate
			,CASE WHEN z.comstatus = 'CO' THEN 1 ELSE 0 END AS IsCancelCashOut
			,z.winlost
	FROM	dbo.zzzbettrans z WITH(NOLOCK)
	WHERE	z.VoidingHistoryId = @VoidingHistoryId
		AND z.SiteDBGroupID = @SiteDBGroupID

	-- parlay ticket
	INSERT INTO #tmpTicket (subTransId, matchid, Refno, SubStatus, VoidedTime, custid, oddsid, SiteDBGroupID, winlostdate)
	SELECT	zm.transid		
			,zm.matchid
			,zm.refno
			,zm.status AS SubStatus
			,zm.transdate AS VoidedTime
			,zm.custid
			,zm.oddsid
			,zm.SiteDBGroupID
			,zm.winlostdate
	FROM	dbo.zzzbettransm zm WITH(NOLOCK)
	WHERE	zm.VoidingHistoryId = @VoidingHistoryId
		AND zm.SiteDBGroupID = @SiteDBGroupID

	UPDATE t 
		SET Betcheck = b.betcheck
			,betdaqid = b.betdaqid
			,betid = b.betid
			,betteam = b.betteam
			,bettype = b.bettype
			,ExtraInfo = b.ExtraInfo
			,hdp1 = b.hdp1
			,hdp2 = b.hdp2
			,liveawayscore = b.liveawayscore
			,livehomescore = b.livehomescore
			,oddsspread = b.oddsspread
			,oddstype = b.oddstype
			,RefCode = b.RefCode
			,stake = b.stake
			,transdesc = b.transdesc
			,Username = b.Username
			,BonusId = b.BonusID
			,WalletType = b.WalletType
			,winlost = t.winlost - b.actual_stake
			,currency = b.currency
			,CurrencyName = b.CurrencyName
			,betfrom = b.betfrom
			,transdate = b.transdate
			,refno = b.refno
			,srecommend = b.srecommend
			,mrecommend = b.mrecommend
			,recommend = b.recommend
			,LiveIndicator = b.liveindicator
			,ActualStake = b.actual_stake
			,IsCashOut = CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END
			,IsMixParlay = CASE WHEN t.Bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END
			,modds = b.modds
	FROM	#tmpTicket t
		INNER JOIN dbo.bettrans b WITH(NOLOCK)
			ON t.TransId = b.transid AND t.SiteDBGroupID = b.SiteDBGroupID
			
	--For void14 abnormal account only (only single + main parlay)
	IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket t
					INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON b.transid = t.TransId)
	BEGIN
		UPDATE t 
			SET Betcheck = b.betcheck
				,betdaqid = b.betdaqid
				,betid = b.betid
				,betteam = b.betteam
				,bettype = b.bettype
				,ExtraInfo = b.ExtraInfo
				,hdp1 = b.hdp1
				,hdp2 = b.hdp2
				,liveawayscore = b.liveawayscore
				,livehomescore = b.livehomescore
				,oddsspread = b.oddsspread
				,oddstype = b.oddstype
				,RefCode = b.RefCode
				,stake = b.stake
				,transdesc = b.transdesc
				,Username = b.Username
				,BonusId = b.BonusID
				,WalletType = b.WalletType
				,winlost = t.winlost - b.actual_stake
				,currency = b.currency
				,CurrencyName = b.CurrencyName
				,betfrom = b.betfrom
				,transdate = b.transdate
				,refno = b.refno
				,srecommend = b.srecommend
				,mrecommend = b.mrecommend
				,recommend = b.recommend
				,LiveIndicator = b.liveindicator
				,ActualStake = b.actual_stake
				,IsCashOut = CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END
				,IsMixParlay = CASE WHEN t.Bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END
				,IsVoidArchived = 1
				,modds = b.modds
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK)
				ON t.TransId = b.transid AND t.SiteDBGroupID = b.SiteDBGroupID

		IF @IsInsertRoutineTask = 1
		BEGIN
			-- Insert RoutineTask
			DECLARE @AffectedList VARCHAR(MAX) 
				,@IsSiteDB			BIT 

			IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
				SET @IsSiteDB = 1

			SET @AffectedList = CAST((
				SELECT	DISTINCT CustId AS '@c'
						,WinlostDate AS '@w'
				FROM	#tmpTicket 
				WHERE IsVoidArchived = 1
				FOR XML PATH('r'), ROOT('root'), TYPE
			) AS VARCHAR(MAX))
	
			BEGIN TRY
				-- insert routine task
				EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
					@AffectedList = @AffectedList
					,@IsSiteDB = @IsSiteDB
			END TRY
			BEGIN CATCH
				SELECT	ERROR_PROCEDURE () + ERROR_MESSAGE()
			END CATCH
		END
	END

	UPDATE	t
		SET transid = b.transid
			,Betcheck = b.betcheck
			,betdaqid = b.betdaqid
			,betid = b.betid
			,betteam = b.betteam
			,bettype = b.bettype
			,ExtraInfo = b.ExtraInfo
			,hdp1 = b.hdp1
			,hdp2 = b.hdp2
			,liveawayscore = bm.liveawayscore
			,livehomescore = bm.livehomescore
			,odds = b.odds
			,oddsspread = b.oddsspread
			,oddstype = b.oddstype
			,RefCode = b.RefCode
			,stake = b.stake
			,transdesc = b.transdesc
			,Username = b.Username
			,BonusID = b.BonusID
			,WalletType = b.WalletType
			,winlost = b.winlost
			,currency = b.currency
			,CurrencyName = b.CurrencyName
			,betfrom = b.betfrom
			,transdate = b.transdate
			,IsMixParlay = 1
			,subbetcheck = bm.betcheck
			,subOdds = bm.odds
			,subbetteam = bm.betteam
			,subbettype = bm.bettype
			,subhdp1 = bm.hdp1
			,subhdp2 = bm.hdp2
			,subtransdesc = bm.transdesc
			,srecommend = b.srecommend
			,mrecommend = b.mrecommend
			,recommend = b.recommend
			,LiveIndicator = bm.liveindicator
			,ActualStake = b.actual_stake
			,t.Status = b.status
			,modds = b.modds
	FROM	#tmpTicket t
		INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK) ON t.subTransId = bm.transid AND t.SiteDBGroupID = bm.SiteDBGroupID
		INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND t.SiteDBGroupID = b.SiteDBGroupID
	WHERE b.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	
	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE IsMixParlay = 0 AND IsVoidArchived = 0))
	BEGIN
		UPDATE t
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,matchid    = m.matchid
			,SettlementStatus = m.SettlementStatus
			,eventstatus = m.eventstatus
			,LeagueGroupID = l.LeagueGroupID
		FROM #tmpTicket t
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	t.matchid = m.matchid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	m.leagueid = l.leagueid
		WHERE t.IsMixParlay = 0 AND IsVoidArchived = 0
	END

	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (10) AND IsVoidArchived = 0))
	BEGIN
		UPDATE t
		SET matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
			,eventstatus = odds.oddsstatus
			,LeagueGroupID = l.LeagueGroupID
		FROM #tmpTicket t
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	t.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE t.bettype IN (10) AND IsVoidArchived = 0
	END

	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (1231,1232,1233,1237,1238) AND IsVoidArchived = 0))
	BEGIN
		UPDATE t
			SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= r.leagueid
				,sporttype 	= r.sporttype
				,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113)
				,eventstatus = o.EventStatus
		FROM #tmpTicket t
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON t.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE t.bettype IN (1231,1232,1233,1237,1238) AND IsVoidArchived = 0
	END

	-- UPDATE Sportype, Endtime VS5
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype BETWEEN 11050 AND 11099))
	BEGIN
		UPDATE d
		SET  matchcode 	= m.MatchNo
			,homeid 	= m.HomeId
			,awayid 	= m.AwayId
			,leagueid 	= m.League3rdId
			,sporttype 	= m.SportType
		FROM #tmpTicket d
			INNER JOIN dbo.Match3rd m WITH (NOLOCK) 
			ON d.matchid = m.Match3rdId
	END

	--For void14 abnormal account only (only single + main parlay)
	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE IsMixParlay = 0 AND IsVoidArchived = 1))
	BEGIN
		UPDATE t
		SET matchcode 	= m.matchcode
			,homeid 	= m.homeid
			,awayid 	= m.awayid
			,leagueid 	= m.leagueid
			,sporttype 	= m.sporttype
			,IsNeutral 	= ISNULL(m.IsNeutral, CONVERT(BIT, 0))
			,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
			,matchid    = m.matchid
			,SettlementStatus = 0
			,eventstatus = m.eventstatus
				,LeagueGroupID = l.LeagueGroupID
		FROM #tmpTicket t
			INNER JOIN dbo.match14 m WITH (NOLOCK) 
				INNER JOIN dbo.league l WITH (NOLOCK) 
					ON	m.leagueid = l.leagueid
			ON	t.matchid = m.matchid
		WHERE t.IsMixParlay = 0 AND IsVoidArchived = 1
	END

	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (10) AND IsVoidArchived = 1))
	BEGIN
		UPDATE t
		SET matchcode 	= odds.matchcode
			,homeid		= odds.teamid
			,awayid 	= 0
			,leagueid 	= odds.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
			,eventstatus = odds.oddsstatus
					,LeagueGroupID = l.LeagueGroupID
		FROM #tmpTicket t
			INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) 
			ON	t.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE t.bettype IN (10) AND IsVoidArchived = 1
	END

	IF(EXISTS(SELECT TOP 1 1 FROM #tmpTicket WHERE bettype IN (1231,1232,1233,1237,1238) AND IsVoidArchived = 1))
	BEGIN
		UPDATE t
			SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= r.leagueid
				,sporttype 	= r.sporttype
				,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113)
				,eventstatus = o.EventStatus
		FROM #tmpTicket t
			INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
			ON t.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE t.bettype IN (1231,1232,1233,1237,1238) AND IsVoidArchived = 1
	END

	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE t
		SET sporttype = sb.SportType
		FROM #tmpTicket t
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON t.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- update Isdeposit
	UPDATE al SET IsDeposit = 1
	FROM #tmpTicket al
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = al.srecommend)

	--get list VIP Account
	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	SELECT  @query = N''		
	SELECT	@query = @query + N'SELECT Custid 
								FROM dbo.Dep_CustVIP WITH (NOLOCK)	
								'
	SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
	INSERT INTO @VIPAccount_tmp(CustID)
	EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query

	BEGIN -- Instant Settlement declaration			
		DECLARE @eventstatus_completed NVARCHAR(50) = 'completed'
		CREATE TABLE #CTE_match (matchid INT, sporttype SMALLINT)
		CREATE TABLE #CTE_isCal (matchid INT, IsHTCal BIT, ResourceId VARCHAR(20))

		INSERT INTO #CTE_match (matchid, sporttype)
		SELECT DISTINCT matchid, sporttype
		FROM #tmpTicket
		WHERE eventstatus <> @eventstatus_completed
		    AND sporttype IN (1,2)
			
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 1) --Soccer	 
		BEGIN 
			INSERT INTO #CTE_isCal (matchid, IsHTCal)
			SELECT m.matchid, ISNULL(mr.IsHTCal, 0) AS IsHTCal
			FROM #CTE_match m
				LEFT JOIN dbo.match_remark mr WITH (NOLOCK) ON mr.matchid = m.matchid
			WHERE m.sporttype = 1

			--> Build bettype list supported for instant settlement based on settlement status of match
			INSERT INTO #InstantSettlementBettypes (matchid, bettype)
			SELECT c.matchid,  f.bettype
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype
						FROM dbo.f_TVS_GetInstantBettypes() 
						WHERE 1 = CASE WHEN c.IsHTCal = 0 AND InstantType IN (1, 3) THEN 1
									   WHEN c.IsHTCal > 0 AND InstantType IN (2, 3) THEN 1
									ELSE 0 END
				)f	 	
		END
		IF EXISTS (SELECT TOP 1 1 FROM #CTE_match WHERE sporttype = 2) --Basketball
		BEGIN
			INSERT INTO #CTE_isCal (matchid, ResourceId)
			SELECT m.matchid, rd.ResourceId
			FROM #CTE_match m
				LEFT JOIN DBPRO.bodb02.dbo.ResultDetail rd WITH (NOLOCK) 
					ON rd.matchid = m.matchid 
					AND ResultStatusID IN (2,5) AND (ResourceId LIKE 'Q[1-4]' OR ResourceId IN ('01','OT')) 
			WHERE m.sporttype = 2

			INSERT INTO #InstantSettlementBettypes (matchid, bettype, betid)
			SELECT DISTINCT c.matchid, f.bettype, f.betid
			FROM #CTE_isCal c
				CROSS APPLY (
						SELECT bettype, betid
						FROM dbo.f_TVS_GetInstantBettypes()
						WHERE InstantType IS NULL
						AND 1 = CASE WHEN c.ResourceId IS NULL THEN 1 --NOT executed on this match.
									 WHEN c.ResourceId IS NOT NULL AND ResourceId NOT IN (SELECT ResourceId FROM #CTE_isCal) THEN 1
									 ELSE 0 END
				)f	 	
		END
			
		DROP TABLE #CTE_match
		DROP TABLE #CTE_isCal
	END	

	--- BETS: return all additional information for mailing 
	CREATE TABLE #CTE_CustInfo (CustId INT, UserName VARCHAR(30), Username2 VARCHAR(50), Site VARCHAR(10))
	;WITH CTE_CustIdAll AS (
		SELECT DISTINCT t.custid
		FROM #tmpTicket b
		CROSS APPLY (
			VALUES (custid)
			,(recommend)
			,(mrecommend)
			,(srecommend)
		) AS t (custid)
	)
	INSERT INTO #CTE_CustInfo(custid, username, username2, site)
	SELECT ci.custid
		, ci.username
		, ci.username2
		, ci.site
	FROM CustDB.dbo.Customer ci WITH(NOLOCK)
		INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid			

	SELECT	t.homeid
			,t.awayId
			,t.leagueid
			,t.sporttype
			,t.matchcode
			,t.showtime 
			,t.isneutral
			,t.matchid
			,t.TransId
			,t.Refno
			,t.TransDate
			,t.Stake
			,t.winlost
			,t.Status
			,t.Betcheck
			,t.betdaqid
			,t.betid
			,t.betfrom
			,t.Betteam
			,t.Bettype AS BetTypeId
			,t.Currency
			,t.CurrencyName	
			,t.Hdp1 AS Handicap1
			,t.Hdp2 AS Handicap2 
			,t.LiveAwayScore
			,t.LiveHomeScore
			,t.Odds
			,t.Oddsspread
			,t.oddstype
			,t.WalletType
			,t.RefCode
			,t.ExtraInfo
			,t.TransDesc
			,t.IsMixParlay
			,t.subTransId
			,t.subbetcheck
			,t.subOdds
			,t.subbetteam
			,t.subbettype
			,t.subhdp1
			,t.subhdp2
			,t.subtransdesc
			,t.SubStatus
			,t.custId
			,t.recommend
			,t.mrecommend
			,t.srecommend
			,c.username
			,c.username2
			,ag.username AS AgUserName
			,ma.username AS MagUserName
			,su.username AS SagUserName
			,CASE WHEN ag.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'BetFair'
				  ELSE su.site END AS EmailGroup
			,su.site
			,t.IsCashOut
			,@IsITSupport AS IsITSupport
			,@IsITSupportCreatedRequest AS IsITSupportCreatedRequest
			,t.SettlementStatus
			,t.LiveIndicator AS IsLive
			,t.ActualStake
			,t.MainTransId
			,CASE 
				WHEN ISNULL(t.eventstatus, '') <> @eventstatus_completed AND t.status IN ('won', 'lose', 'draw') AND ISNULL(t.betdaqid,0) <> -2
						THEN CASE WHEN t.sporttype = 1
										AND EXISTS (SELECT TOP 1 1
													FROM #InstantSettlementBettypes
													WHERE bettype = t.bettype)
										THEN 1
								  WHEN t.sporttype = 2
										AND EXISTS (SELECT TOP 1 1
													FROM #InstantSettlementBettypes
													WHERE bettype = t.bettype AND (betid = t.betid OR t.betid IS NULL))
										THEN 1
								ELSE 0 END
				ELSE 0
			END AS IsInstantSettlementTicket
			,CASE WHEN vip.CustID IS NOT NULL THEN 1 ELSE 0 END AS IsVipMember
			,t.IsDeposit --0: Credit - Notify Letstalk when void Abnormal Bets
			,t.SiteDBGroupID
			,t.winlostdate
			,ISNULL(t.IsCancelCashOut,0) AS IsCancelCashOut
			,t.LeagueGroupID
			,ISNULL(si.IsChinaView,0) AS IsChinaView
			,ISNULL(si.SpecialPlatfrom,0) AS SpecialPlatform --2: JollyView, 3: JollyView CV
			,@VoidingHistoryId AS VoidingHistoryId
			,t.zzzWinlost
			,t.modds AS MasterOdds
	FROM	#tmpTicket t
		LEFT JOIN #CTE_CustInfo c WITH(NOLOCK) ON c.custid = t.custid
		LEFT JOIN #CTE_CustInfo ag WITH(NOLOCK) ON ag.custid = t.recommend 
		LEFT JOIN #CTE_CustInfo ma WITH(NOLOCK) ON ma.custid = t.mrecommend
		LEFT JOIN #CTE_CustInfo su WITH(NOLOCK) ON su.custid = t.srecommend
		LEFT JOIN @VIPAccount_tmp vip ON t.custid = vip.CustID 	
		LEFT JOIN custDB.dbo.Site si WITH(NOLOCK) ON su.site = si.site
	ORDER BY ISNULL(t.MainTransId, t.transid)
		   , CASE 
				WHEN t.BonusID IS NOT NULL
						THEN CASE 
								WHEN t.MainTransId IS NULL THEN 1
								ELSE 2 
							 END
				ELSE t.transid
			 END

	DROP TABLE #tmpTicket;
	DROP TABLE #InstantSettlementBettypes
	DROP TABLE #CTE_CustInfo
END
GO
