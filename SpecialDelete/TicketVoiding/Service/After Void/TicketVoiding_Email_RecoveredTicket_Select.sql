/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" isFunction="0"></info>*/
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
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20240102@July: Create new SP [Redmine:#196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240506@July: [TVS] Separate Parlay group of the Bet list [Redmine: #203654]
	Param's explanation:	
		
*/	
BEGIN
	SET NOCOUNT ON

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
		,Winlost		MONEY
		,Status			NVARCHAR(10)
		,Betcheck		NVARCHAR(50)
		,betdaqid		BIGINT
		,betid			BIGINT
		,betfrom		NVARCHAR(4)
		,Betteam		NVARCHAR(10)
		,Bettype		SMALLINT
		,CurrencyName	NVARCHAR(50)
		,Hdp1			SMALLMONEY
		,Hdp2			SMALLMONEY
		,livehomescore	SMALLINT
		,liveawayscore	SMALLINT
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
		,MainTransId 	BIGINT
		,IsLiveIndicator  BIT
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
		,SiteDBGroupID	SMALLINT
		,winlostdate	SMALLDATETIME
		,IsMove14		BIT
		,IsCashOut		BIT DEFAULT(0)
		,IsSettled		BIT DEFAULT(0)
		,IsDeposit		BIT DEFAULT(0) --1: Deposit/ 0: Credit
		,modds			SMALLMONEY
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
			,IsLiveIndicator 
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
			,IsCashOut
			,modds
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
			,z.winlost - b.actual_stake AS WinLost    
			,b.actual_stake 
			,z.status
			,z.status AS SubStatus 
			,b.betteam AS Subbetteam  
			,b.transdesc SubTransdesc  
			,b.SiteDBGroupID
			,b.oddsid
			,b.winlostdate
			,b.Username
			,b.transid AS MainTransId
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.modds
		FROM #transIdTemp d 
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON d.transid = b.TransId
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype
					AND z.SiteDBGroupID = b.SiteDBGroupID
		WHERE b.statusID NOT IN (101, 102)
			AND b.SiteDBGroupID = @SiteDBGroupID
			AND d.TicketType = 1
		
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
			,IsLiveIndicator 
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
			,IsCashOut
			,modds
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
			,z.winlost - b.actual_stake AS WinLost    
			,b.actual_stake 
			,z.Status
			,z.status AS SubStatus 
			,b.betteam AS Subbetteam  
			,b.transdesc SubTransdesc  
			,b.SiteDBGroupID
			,b.oddsid
			,b.winlostdate
			,b.Username
			,1 AS IsMove14
			,b.transid AS MainTransId
			,CASE WHEN b.betdaqid = -2 THEN 1 ELSE 0 END AS IsCashOut
			,b.modds
		FROM #transIdTemp d 
			INNER JOIN dbo.bettrans14 b WITH (NOLOCK) ON d.transid = b.TransId
			INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
				ON	b.transid = z.transid
					AND z.custid = b.custid
					AND z.matchid = b.matchid
					AND z.bettype = b.bettype
					AND z.SiteDBGroupID = b.SiteDBGroupID
		WHERE b.statusID NOT IN (101, 102)
			AND b.SiteDBGroupID = @SiteDBGroupID
			AND d.TicketType = 1
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
					,@Action = 'Recover_14'
			END TRY
			BEGIN CATCH
				SELECT	ERROR_PROCEDURE () + ERROR_MESSAGE()
			END CATCH
		END
	END

	-- UPDATE eventtype = 1
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (9, 29, 2799, 10449)))
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
		FROM #TVSTicketBets t
			INNER JOIN dbo.match m WITH (NOLOCK) 
			ON	t.matchid = m.matchid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	m.leagueid = l.leagueid
		WHERE t.bettype NOT IN (9, 29, 2799, 10449)
	END

	-- UPDATE eventtype = 2 [Outright bettype]
	IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (10)))
	BEGIN
		UPDATE t
		SET matchcode 	= o.matchcode
			,homeid		= o.teamid
			,awayid 	= 0
			,leagueid 	= o.leagueid
			,sporttype 	= l.sporttype
			,showtime	= ''
			,eventstatus = o.oddsstatus
		FROM #TVSTicketBets t
			INNER JOIN dbo.outright AS o WITH (NOLOCK) 
			ON	t.matchid = o.orid
			INNER JOIN dbo.league l WITH (NOLOCK) 
			ON	o.leagueid = l.leagueid
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
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype NOT IN (9, 29, 2799, 10449)))
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
			WHERE t.bettype NOT IN (9, 29, 2799, 10449)
		END

		-- UPDATE eventtype = 2 [Outright bettype]
		IF(EXISTS(SELECT TOP 1 1 FROM #TVSTicketBets WHERE bettype IN (10)))
		BEGIN
			UPDATE t
			SET matchcode 	= o.matchcode
				,homeid		= o.teamid
				,awayid 	= 0
				,leagueid 	= o.leagueid
				,sporttype 	= l.sporttype
				,showtime	= ''
				,eventstatus = o.oddsstatus
			FROM #TVSTicketBets t
				INNER JOIN dbo.outright14 AS o WITH (NOLOCK) 
				ON	t.matchid = o.orid
				INNER JOIN dbo.league l WITH (NOLOCK) 
				ON	o.leagueid = l.leagueid
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
	UPDATE t SET IsDeposit = 1
	FROM #TVSTicketBets t
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = t.srecommend)

	SELECT  t.TransId    
		   ,t.MatchId
		   ,t.UserName
		   ,t.Odds     
		   ,t.OddsType
		   ,t.TransDate     
		   ,t.Bettype    
		   ,t.BetTeam    
		   ,t.hdp1     
		   ,t.hdp2    
		   ,t.livehomescore    
		   ,t.liveawayscore  
		   ,t.Stake     
		   ,SUBSTRING(gr.GroupName, 3, 30) AS GroupName
		   ,t.Status     
		   ,t.homeid
		   ,t.awayid  
		   ,t.IsLiveIndicator
		   ,t.Winlost   
		   ,t.betid  
		   ,t.Refno     
		   ,t.sporttype     
		   ,t.leagueid
		   ,t.betcheck    
		   ,t.transdesc  
		   ,t.ExtraInfo
		   ,t.betdaqid
		   ,t.WalletType
		   ,t.MainTransId
		   ,t.RefCode
		   ,t.Oddsspread
		   ,t.SettlementStatus
		   ,t.actual_stake AS ActualStake
		   ,t.custid
		   ,t.SiteDBGroupID
		   ,t.betfrom
		   ,CASE WHEN c.currency <> 20 OR (c.currency = 20 AND @IsITSupport = 0 )THEN 1 ELSE 0 END AS IsCSD --Recover real tickets => send mail to CSD , Recover UUS tickets by CSD: send mail CSD
		   ,CASE WHEN c.currency <> 20 AND @IsITSupport = 1 THEN 1 ELSE 0 END AS IsITSupport -- Recover real tickets by IT ==> Send mail with recipient list "IT Support"
		   ,CASE WHEN c.currency = 20 AND @IsITSupport = 1 THEN 1 ELSE 0 END AS IsITQA -- Recover UUS tickets by IT => Send mail with recipient list "IT QA"
		   ,t.IsCashOut 
		   ,CASE WHEN t.IsCashOut = 0 AND t.eventstatus = 'completed' THEN 1 ELSE 0 END AS IsSettled
		   ,t.CurrencyName
		   ,t.modds AS MasterOdds
		   ,t.IsDeposit
	FROM	#TVSTicketBets t
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = t.srecommend
		LEFT JOIN dbo.f_GetBetDaqCustomer(1) f ON t.custid = f.CustID
		CROSS APPLY (SELECT CASE
								WHEN f.CustID IS NULL
									AND t.username <> '12EU'
									AND t.IsDeposit = 0
									AND t.mrecommend NOT IN (105181, 118473, 105183) -- MHC
									AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet, 1E, 8RM
									AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058)
										THEN '0-Credit' --1. For Normal bets
								WHEN t.recommend IN (52466, 5707545)
										THEN '1-8RM/BARM' ----2: For 8RM/BARM
								WHEN f.CustID IS NULL -- Betdaq
									AND t.username <> '12EU' 
									AND t.IsDeposit = 1	
									AND t.mrecommend NOT IN (105181, 118473, 105183)
									AND t.recommend NOT IN (11196380, 13423967, 52466) -- Foobet: 11196380, 1E: 13423967, 8RM: 52466
									AND t.custid NOT IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
										THEN '2-Deposit' ----3. For Deposit bets
								WHEN t.custid IN (1077687,2331,115770,15523642,15042477,16041068,16041058) -- Betfair: BFOS, BF, ITibc102, BF3
										THEN '3-BetFair' ----8: For Betfair
								ELSE NULL
							END AS GroupName) AS gr	
	WHERE gr.GroupName IS NOT NULL
	ORDER BY gr.GroupName, t.transid	

	DROP TABLE #transIdTemp
	DROP TABLE #TVSTicketBets;

END
GO
