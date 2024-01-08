/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Email_RecoveredTicket_Select](
	 @SingleTransIds			VARCHAR(MAX) = NULL
	,@IsITSupport				BIT = 0
	,@IsITSupportCreatedRequest BIT = 0
	,@SiteDBGroupID				SMALLINT = 0
	,@IsInsertRoutineTask		BIT = 0
)AS
/*	
	Created by: 20240102@July
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20240102@July: Create new SP [Redmine:#196020]
		
	Param's explanation:	
		
*/	
BEGIN
	SET NOCOUNT ON

	DECLARE @query NVARCHAR(MAX) = ''
		   ,@ExecuteSQL NVARCHAR(MAX) = ''

	CREATE TABLE #TVSTicketBets (
		TransId			BIGINT
		,matchid		INT
		,custid			INT
		,recommend		INT
		,mrecommend		INT
		,Srecommend		INT
		,TransDate		DATETIME
		,actual_stake	MONEY
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
		,isITAdmin		BIT
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
		,IsDeposit      BIT DEFAULT(0)
		,SiteDBGroupID	SMALLINT
		,winlostdate	SMALLDATETIME
		,IsCancelCashOut BIT
		,IsMove14		BIT
		,LeagueGroupID  SMALLINT
	)

	CREATE TABLE #transIdTemp (
		transid		BIGINT PRIMARY KEY
	   ,TicketType	TINYINT --1: single(exclude cancel CO), 2: parlay, 3: cancel CO
	) 

	INSERT INTO #transIdTemp (transid, TicketType)
	SELECT DISTINCT value, 1
	FROM STRING_SPLIT(@SingleTransIds, ',')
	WHERE value <> ''

	--Search single tickets (active & archive 14)
	BEGIN
		INSERT INTO #TVSTicketBets(
			matchid 
			,transid
			,Subtransid 
			,custid                
			,transdate 
			,hdp1 
			,hdp2 
			,livehomescore 
			,liveawayscore 
			,liveindicator 
			,betteam 
			,refno 
			,betid 
			,bettype 
			,betdaqid 
			,betfrom 
			,WalletType 
			,RefCode 
			,Subhdp1 
			,Subhdp2 
			,Subbettype 
			,recommend 
			,mrecommend 
			,srecommend 
			,IsMixParlay 
			,odds 
			,Subodds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,Subbetcheck 
			,stake 
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,SubStatus 
			,Subbetteam  
			,SubTransdesc  
			,SiteDBGroupID
			,oddsid
			,winlostdate
			,username
			,MainTransId
		)
		SELECT b.matchid
			,b.TransId
			,b.transid AS SubTransID
			,b.custid
			,b.transdate
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.betteam
			,b.refno
			,b.betid
			,b.bettype
			,b.betdaqid 
			,b.betfrom 
			,b.WalletType 
			,b.RefCode 
			,b.hdp1 AS Subhdp1 
			,b.hdp2 AS Subhdp2 
			,b.bettype AS Subbettype 
			,b.recommend 
			,b.mrecommend 
			,b.srecommend 
			,CASE WHEN b.Bettype = 29 THEN 1 ELSE 0 END AS IsMixParlay 
			,b.odds 
			,b.odds AS Subodds 
			,b.oddsspread
			,b.oddstype 
			,b.betcheck 
			,b.betcheck AS Subbetcheck 
			,b.stake 
			,b.CurrencyName 
			,b.Transdesc 
			,b.ExtraInfo 
			,b.BonusID 
			,b.winlost        
			,b.actual_stake 
			,b.Status
			,b.status AS SubStatus 
			,b.betteam AS Subbetteam  
			,b.transdesc SubTransdesc  
			,b.SiteDBGroupID
			,b.oddsid
			,b.winlostdate
			,b.Username
			,b.transid AS MainTransId
		FROM #transIdTemp d 
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON d.transid = b.TransId
		WHERE b.statusID NOT IN (101, 102, 103)
			AND b.SiteDBGroupID = @SiteDBGroupID
		
		INSERT INTO #TVSTicketBets(
			matchid 
			,transid
			,Subtransid 
			,custid                
			,transdate 
			,hdp1 
			,hdp2 
			,livehomescore 
			,liveawayscore 
			,liveindicator 
			,betteam 
			,refno 
			,betid 
			,bettype 
			,betdaqid 
			,betfrom 
			,WalletType 
			,RefCode 
			,Subhdp1 
			,Subhdp2 
			,Subbettype 
			,recommend 
			,mrecommend 
			,srecommend 
			,IsMixParlay 
			,odds 
			,Subodds 
			,oddsspread 
			,oddstype 
			,betcheck 
			,Subbetcheck 
			,stake 
			,CurrencyName 
			,Transdesc 
			,ExtraInfo 
			,BonusID 
			,winlost        
			,actual_stake 
			,Status
			,SubStatus 
			,Subbetteam  
			,SubTransdesc  
			,SiteDBGroupID
			,oddsid
			,winlostdate
			,username
			,IsMove14
			,MainTransId
		)
		SELECT b.matchid
			,b.TransId
			,b.transid AS SubTransID
			,b.custid
			,b.transdate
			,b.hdp1
			,b.hdp2
			,b.livehomescore
			,b.liveawayscore
			,b.liveindicator
			,b.betteam
			,b.refno
			,b.betid
			,b.bettype
			,b.betdaqid 
			,b.betfrom 
			,b.WalletType 
			,b.RefCode 
			,b.hdp1 AS Subhdp1 
			,b.hdp2 AS Subhdp2 
			,b.bettype AS Subbettype 
			,b.recommend 
			,b.mrecommend 
			,b.srecommend 
			,CASE WHEN b.Bettype = 29 THEN 1 ELSE 0 END AS IsMixParlay
			,b.odds 
			,b.odds AS Subodds 
			,b.oddsspread
			,b.oddstype 
			,b.betcheck 
			,b.betcheck AS Subbetcheck 
			,b.stake 
			,b.CurrencyName 
			,b.Transdesc 
			,b.ExtraInfo 
			,b.BonusID 
			,b.winlost        
			,b.actual_stake 
			,b.Status
			,b.status AS SubStatus 
			,b.betteam AS Subbetteam  
			,b.transdesc SubTransdesc  
			,b.SiteDBGroupID
			,b.oddsid
			,b.winlostdate
			,b.Username
			,1 AS IsMove14
			,b.transid AS MainTransId
		FROM #transIdTemp d 
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON d.transid = b.TransId
		WHERE b.statusID NOT IN (101, 102, 103)
			AND b.SiteDBGroupID = @SiteDBGroupID
	END

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsMove14 = 1)
	BEGIN
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
				FROM	#TVSTicketBets 
				WHERE IsMove14 = 1
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

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (9, 29, 2799)))
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
		FROM #TVSTicketBets t
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	t.matchid = m.matchid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	m.leagueid = l.leagueid
		WHERE t.bettype NOT IN (9, 29, 2799)
	END

	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (10)))
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
		FROM #TVSTicketBets t
			INNER JOIN dbo.outright AS odds WITH (NOLOCK) 
			ON	t.matchid = odds.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	odds.leagueid = l.leagueid
		WHERE t.bettype IN (10)
	END
	-- UPDATE eventtype = 3 [VS range  bettypes]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (1231,1232,1233,1237,1238)))
	BEGIN
		UPDATE t
			SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= r.leagueid
				,sporttype 	= r.sporttype
				,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113)
				,eventstatus = o.EventStatus
		FROM #TVSTicketBets t
			INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
			ON t.oddsid = o.Orid
			INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
			ON r.EventID = o.EventID
		WHERE t.bettype IN (1231,1232,1233,1237,1238)
	END

	IF EXISTS (SELECT TOP 1 1 FROM #TVSTicketBets WHERE IsMove14 = 1)
	BEGIN
		-- UPDATE eventtype = 1
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (9, 29, 2799)))
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
			FROM #TVSTicketBets t
				INNER JOIN dbo.match14 m WITH (NOLOCK) 
				ON	t.matchid = m.matchid
			WHERE t.bettype NOT IN (9, 29, 2799)
		END

		-- UPDATE eventtype = 2 [Outright bettype]
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (10)))
		BEGIN
			UPDATE t
			SET matchcode 	= odds.matchcode
				,homeid		= odds.teamid
				,awayid 	= 0
				,leagueid 	= odds.leagueid
				,sporttype 	= l.sporttype
				,showtime	= ''
				,eventstatus = odds.oddsstatus
			FROM #TVSTicketBets t
				INNER JOIN dbo.outright14 AS odds WITH (NOLOCK) 
				ON	t.matchid = odds.orid
				INNER JOIN dbo.league l WITH (NOLOCK) 
				ON	odds.leagueid = l.leagueid
			WHERE t.bettype IN (10)
		END
		-- UPDATE eventtype = 3 [VS range  bettypes]
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (1231,1232,1233,1237,1238)))
		BEGIN
			UPDATE t
				SET matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
					,homeid 	= o.RacerID
					,awayid 	= 0
					,leagueid 	= r.leagueid
					,sporttype 	= r.sporttype
					,showtime	= CONVERT(VARCHAR(20), r.EventTime, 113)
					,eventstatus = o.EventStatus
			FROM #TVSTicketBets t
				INNER JOIN dbo.VSOutright14 o WITH (NOLOCK) 
				ON t.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo14 r WITH (NOLOCK) 
				ON r.EventID = o.EventID
			WHERE t.bettype IN (1231,1232,1233,1237,1238)
		END
	END

	-- UPDATE Sportype for Saba Promotion (bettype = 17000, 17003)
	BEGIN
		UPDATE t
		SET sporttype = sb.SportType
		FROM #TVSTicketBets t
			INNER JOIN dbo.SportBettypeMatrix sb WITH (NOLOCK)
			ON t.bettype = sb.BetType
		WHERE sb.ProductID = 37
	END

	-- update Isdeposit
	UPDATE al SET IsDeposit = 1
	FROM #TVSTicketBets al
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
			,t.actual_stake
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
			,CASE 
				WHEN ag.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) THEN 'BetFair'
				ELSE su.site
			END AS EmailGroup
			,su.site
			,t.IsCashOut
			,@IsITSupport AS IsITSupport
			,@IsITSupportCreatedRequest AS IsITSupportCreatedRequest
			,t.SettlementStatus
			,t.LiveIndicator AS IsLive
			,t.ActualStake
			,t.MainTransId
			,CASE WHEN vip.CustID IS NOT NULL THEN 1 ELSE 0 END AS IsVipMember
			,CASE WHEN f.CustID IS NULL AND (t.username <> '12EU')  AND t.IsDeposit = 0
				    AND t.mrecommend NOT IN (105181, 118473, 105183) -- MHC
				    AND t.recommend NOT IN (11196380, 13423967, 52466, 5707545) -- Foobet, 1E, 8RM, BARM
				    AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)  -- Betfair: BFOS, BF, ITibc102, BF3
					AND c.site <> 'CN88'
			THEN 1 ELSE 0 END IsCredit
			,t.SiteDBGroupID
			,t.winlostdate
			,ISNULL(t.IsCancelCashOut,0) AS IsCancelCashOut
			,t.LeagueGroupID
			,ISNULL(si.IsChinaView,0) AS IsChinaView
			,ISNULL(si.SpecialPlatfrom,0) AS SpecialPlatform --2: JollyView
	FROM	#TVSTicketBets t
		LEFT JOIN dbo.match m WITH(NOLOCK) ON m.matchid = t.matchid
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = t.custid
		LEFT JOIN CustDB.dbo.Customer ag WITH(NOLOCK) ON ag.custid = t.recommend 
		LEFT JOIN CustDB.dbo.Customer ma WITH(NOLOCK) ON ma.custid = t.mrecommend
		LEFT JOIN CustDB.dbo.Customer su WITH(NOLOCK) ON su.custid = t.srecommend
		LEFT JOIN @VIPAccount_tmp vip ON t.custid = vip.CustID 	
		LEFT JOIN dbo.f_GetBetDaqCustomer(1) f ON t.custid = f.CustID
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

	DROP TABLE #TVSTicketBets;

END
GO
