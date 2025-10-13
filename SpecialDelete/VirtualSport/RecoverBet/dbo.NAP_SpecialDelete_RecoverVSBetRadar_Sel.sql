/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverVSBetRadar_Sel] 
	@TicketType			VARCHAR(100),
	@Type				VARCHAR(100)	= NULL,
	@MatchId			INT				= 0,		
	@TransIds			VARCHAR(MAX)	= ''
AS
/*  
	Created by: 20170607@Kent  
	Task: 
	DB: DBTXN/bodb02   

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]			
		- 20180406@Helen: add filter by bettype for sport 181->185 to avoid the same value in table VSOutright (orid) and bettrans (oddsid) [Redmind:93183]
		- 20210712@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220910@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230717@July: [SD] Integrate Virtual Sports 3 (Leap Gaming) [Redmine: #189556]
		- 20231030@July: [TVS] Integrate a new sport type "Virtual Football League" [Redmine: #195313]
		- 20240220@July: Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20241001@Max: [TVS] Virtual Sports 2 (Betradar) - Virtual Horse Racing & Virtual Dog Racing [Redmine: #211105]
		- 20241028@Max: [TVS] Virtual Sports 6 (Betby) - Virtual Betby Basketball [Redmine: #212502]
		- 20250220@Max: [TVS] Recover ticket of Virtual Sports 2 [Redmine: #212323]		
		- 20250324@Max: [TVS] Virtual Sports 7 (Kiron Virtual Sports) [Redmine: #219045]
		- 20251009@July: [TVS] Virtual Sport 6 - Integrate new sport type - 'eSoccer' and 'eVolleyball' [Redmine:#241016]

	Param's Explanation:			
		- @TicketType:		
		'Single': Single ticket
		'Mix Parlay': Parlay ticket
		
		- @Type:		
		'Sub': Sub-parlay ticket
		'Main': Main-parlay ticket
*/
BEGIN
	SET NOCOUNT ON	
	
	DECLARE @before_yesterday	DATETIME
		   ,@Movebetdate		DATETIME
		   ,@InvalidTransIds	VARCHAR(MAX)  = ''
		   ,@MovedTransIds		VARCHAR(MAX)  = '' 
		   ,@SiteDBGroupID		SMALLINT = 0
	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #RecoverBet
	(
		Stake			MONEY,
		AwayId			INT,
		BetCheck		NVARCHAR(50),
		BetId			BIGINT,
		BetTeam			NVARCHAR(10),
		BetType			SMALLINT,
		CurrencyCode	NVARCHAR(50),
		Hdp1			SMALLMONEY,
		Hdp2			SMALLMONEY,
		HomeId			INT,
		IsLiveIndicator BIT,
		LiveAwayScore	SMALLINT,
		LiveHomeScore	SMALLINT,
		Odds			SMALLMONEY,
		OddsType		INT,
		oddsid			INT,
		RefNo			BIGINT,
		SportType		SMALLINT,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		TransDesc		NVARCHAR(1000),
		TransId			BIGINT,
		UserName		VARCHAR(30),
		WinLost			MONEY,
		winlostdate		SMALLDATETIME,
		IsDeposit		BIT DEFAULT(0),
		recommend		INT,
		mrecommend		INT,
		srecommend		INT,
		CustId			INT,
		showtime		NVARCHAR(20),
		LeagueId		INT,
		matchcode		NVARCHAR(50),
		modds			SMALLMONEY,
		EventDate		DATETIME,
		SubStatus		NVARCHAR(10),
		SubTransId		BIGINT,
		SubBetCheck		NVARCHAR(50),
		SubBetTeam		NVARCHAR(10),
		SubBetType		SMALLINT,
		SubHdp1			SMALLMONEY,
		SubHdp2			SMALLMONEY,
		SubOdds			SMALLMONEY,
		SubTransdesc	NVARCHAR(2000),
		VendorMatchId VARCHAR(50),
		MatchId			INT
	)
	
	CREATE TABLE #tblTransIds (transid BIGINT)
	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT)

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT

	--> parse @TransIds
	INSERT INTO #tblTransIds (transid)
	SELECT	t.value
	FROM STRING_SPLIT(@TransIds, ',') t								
	
	SELECT @before_yesterday = CONVERT(varchar(10), DATEADD(day, -2, GETDATE()), 120)
	
	--> search by @TransIds
	IF @TicketType = 'Single' OR (@TicketType = 'Mix Parlay' AND @Type = 'Main')
	BEGIN
		INSERT INTO #RecoverBet(
					Stake,
					BetCheck,
					BetId,
					BetTeam,
					BetType,
					CurrencyCode,
					Hdp1,
					Hdp2,
					IsLiveIndicator,
					LiveAwayScore,
					LiveHomeScore,
					Odds,
					OddsType,
					oddsid,
					RefNo,
					Status,
					TransDate,
					TransDesc,
					TransId,
					UserName,
					WinLost,
					winlostdate,
					recommend,
					mrecommend,
					srecommend,
					CustId,
					modds,
					MatchId)
			SELECT  z.Stake,
					z.BetCheck,
					b.BetId,
					z.BetTeam,
					z.BetType,
					b.CurrencyName AS CurrencyCode,
					z.Hdp1,
					z.Hdp2,
					z.liveindicator AS IsLiveIndicator,
					z.LiveAwayScore,
					z.LiveHomeScore,
					z.Odds,
					b.OddsType,
					b.oddsid,
					z.RefNo,
					z.Status,
					b.TransDate,
					b.TransDesc,
					z.TransId,
					b.UserName,
					z.winlost - b.actual_stake AS WinLost,
					b.winlostdate,
					b.recommend,
					b.mrecommend,
					b.srecommend,
					b.CustId,
					b.modds,
					z.matchid
			FROM  #tblTransIds tbl
				 INNER JOIN dbo.zzzbettrans z WITH (NOLOCK)	ON tbl.transid = z.transid				 
				 INNER JOIN dbo.bettrans b WITH (NOLOCK)
						 ON	z.transid = b.transid
							AND z.custid = b.custid
							AND z.matchid = b.matchid					
							AND z.bettype = b.bettype
			WHERE z.winlostdate >= @before_yesterday
			  AND z.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = z.SiteDBGroupID
		
		IF @TicketType = 'Single'
		BEGIN
			--> VS Betradar, Inspired VS 180, VS 3(Leap Gaming)	
			UPDATE r
			SET  matchcode 	= NULL
				,homeid 	= m.homeid
				,awayid 	= m.awayid
				,leagueid 	= m.leagueid
				,sporttype	= m.SportType
				,showtime	= ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '')
				,eventdate  = m.eventdate
			FROM #RecoverBet r
				CROSS APPLY (
					SELECT m.homeid, m.awayid, m.sporttype, m.leagueid, m.kickofftime, m.matchcode, m.eventdate, m.eventstatus, m.betstatus
					FROM match m WITH (NOLOCK)
					WHERE m.matchid = r.matchid
					UNION 
					SELECT m.homeid, m.awayid, m.sporttype, m.League3rdId AS leagueid, m.StartTime, m.MatchNo AS matchcode, m.EventDate, m.eventstatus, m.betstatus
					FROM Match3rd m WITH (NOLOCK)
					WHERE m.Match3rdId = r.matchid
				 )m			
			WHERE m.sporttype BETWEEN 190 AND 199 -- VS Betradar
				 OR m.sporttype IN (180, 186	-- Inspired VS 
								  , 178, 179	-- VS 3 (Leap Gaming)
								  , 188			-- VS 4 (Edge Gaming)
								  , 147			-- VS5
								  , 134, 116, 114 -- VS6
							) 

			--> Inspired VS 181, Virtual Horse Racing & Virtual Dog Racing
			UPDATE r
			SET  matchcode 	= CONVERT(NVARCHAR(50), o.RacerNum)
				,homeid 	= o.RacerID
				,awayid 	= 0
				,leagueid 	= vs.leagueid
				,sporttype 	= vs.sporttype
				,showtime	= CONVERT(VARCHAR(20), vs.EventTime, 113) 
				,eventdate  = o.eventdate
			FROM #RecoverBet r
				INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
					 ON r.oddsid = o.Orid
				INNER JOIN dbo.VSRaceInfo vs WITH (NOLOCK) 
						 ON vs.EventID = o.EventID		
			WHERE (vs.sporttype BETWEEN 181 AND 185 OR vs.SportType IN (177,198,125,126,127)) -- Inspired VS 181		  				  			  				
				AND r.bettype IN (1231,1232,1233,1237,1238,2770,2771,15500,15501)		
		
			--- Remove invalid ticket
			DELETE d
			FROM #RecoverBet d
			WHERE bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId = 1)
				OR sporttype IS NULL

		END 
		
		IF @TicketType = 'Mix Parlay' AND @Type = 'Main'
		BEGIN
			--- Remove invalid ticket
			DELETE d
			FROM #RecoverBet d
			WHERE bettype NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId = 1)

			UPDATE d
			SET EventDate = d.winlostdate
			FROM #RecoverBet d
		END

		IF EXISTS (SELECT TOP 1 1 FROM #RecoverBet WHERE EventDate <= @MovebetDate)
		BEGIN
			DELETE 
			FROM #RecoverBet
				OUTPUT	DELETED.TransId
				INTO @tmpTransIdMoveBet (TransId)
			WHERE EventDate <= @MovebetDate
		END
		
		--> build @InvalidTransIds, @MovedTransIds				
		;WITH t_invalid AS
		(
			SELECT	t.transid
					,CASE 
						WHEN EXISTS (SELECT TOP 1 1 
									 FROM dbo.bettrans14 b14 WITH(NOLOCK) 
									 WHERE b14.transid = t.transid AND b14.SiteDBGroupID = @SiteDBGroupID) 
								THEN 1 
						WHEN EXISTS (SELECT TOP 1 1 
									 FROM @tmpTransIdMoveBet m
									 WHERE m.TransId = t.transid) 
								THEN 1 
						ELSE 0 
					 END AS isMoved					
			FROM	#tblTransIds t
			WHERE	t.transid NOT IN (SELECT transid FROM #RecoverBet)
		)
		SELECT @InvalidTransIds = @InvalidTransIds +
								  CASE
									  WHEN isMoved = 0
											THEN CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + 
												 CAST(transid AS VARCHAR(50))
									  ELSE ''
								  END								  
			 , @MovedTransIds = @MovedTransIds +
								CASE
									WHEN isMoved = 1
											THEN CASE WHEN @MovedTransIds <> '' THEN ',' ELSE '' END + 
												 CAST(transid AS VARCHAR(50))
									ELSE ''
								END
		FROM t_invalid
	END		
	
	--> search by @TransIds + @MatchId
	IF @TicketType = 'Mix Parlay' AND @Type = 'Sub'
	BEGIN
		--> search tickets
		INSERT INTO #RecoverBet(
				Stake,
				AwayId,
				BetCheck,
				BetId,
				BetTeam,
				BetType,
				CurrencyCode,
				Hdp1,
				Hdp2,
				HomeId,
				IsLiveIndicator,
				LiveAwayScore,
				LiveHomeScore,
				Odds,
				OddsType,
				RefNo,
				SportType,
				Status,
				TransDate,
				TransDesc,
				TransId,
				UserName,
				WinLost,
				recommend,
				mrecommend,
				srecommend,
				CustId,
				showtime,
				LeagueId,
				modds,
				EventDate,
				SubStatus,
				SubTransId,
				SubBetCheck,
				SubBetTeam,
				SubBetType,
				SubHdp1,
				SubHdp2,
				SubOdds,
				SubTransdesc)
		SELECT  b.Stake,
				m.AwayId,
				b.BetCheck,
				b.BetId,
				b.BetTeam,
				b.BetType,
				b.CurrencyName AS CurrencyCode,
				b.Hdp1,
				b.Hdp2,
				m.HomeId,
				b.liveindicator AS IsLiveIndicator,
				b.LiveAwayScore,
				b.LiveHomeScore,
				b.Odds,
				NULL AS OddsType,
				b.RefNo,
				m.SportType,
				b.Status,
				b.TransDate,
				b.TransDesc,
				b.TransId,
				b.UserName,
				b.winlost - b.actual_stake AS WinLost,
				b.recommend,
				b.mrecommend,
				b.srecommend,
				b.CustId,
				ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime,
				m.leagueid,
				b.modds,
				m.EventDate,
				bm.Status AS SubStatus,
				bm.TransId AS SubTransId,
				bm.BetCheck AS SubBetCheck,
				bm.BetTeam AS SubBetTeam,
				bm.BetType AS SubBetType,
				bm.Hdp1 AS SubHdp1,
				bm.Hdp2 AS SubHdp2,
				bm.Odds AS SubOdds,
				bm.transdesc AS SubTransdesc
		FROM dbo.bettrans b WITH (NOLOCK)
			 INNER JOIN bettransm bm WITH (NOLOCK)
					 ON b.refno = bm.refno			 			
			 CROSS APPLY (
					SELECT m.homeid, m.awayid, m.sporttype, m.leagueid, m.kickofftime, m.matchcode, m.eventdate
					FROM match m WITH (NOLOCK)
					WHERE m.matchid = @MatchId
					UNION 
					SELECT m.homeid, m.awayid, m.sporttype, m.League3rdId AS leagueid, m.StartTime, m.matchcode, m.EventDate
					FROM Match3rd m WITH (NOLOCK)
					WHERE m.Match3rdId = @MatchId
				 )m
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
		  AND bm.matchid = @MatchId	
		  AND bm.winlostdate >= @before_yesterday
		  AND b.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1))	
		  AND b.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (1))	
		  AND bm.statusid = 102
		  AND b.statusID NOT IN (101, 102) -- reject, void		  		  		
		  AND b.SiteDBGroupID = @SiteDBGroupID AND bm.SiteDBGroupID = b.SiteDBGroupID

		IF EXISTS (SELECT TOP 1 1 FROM #RecoverBet WHERE EventDate <= @MovebetDate)
		BEGIN
			DELETE 
			FROM #RecoverBet
				OUTPUT	DELETED.TransId
				INTO @tmpTransIdMoveBet (TransId)
			WHERE EventDate <= @MovebetDate
		END 
								
		--> build @InvalidTransIds, @MovedTransIds		
		/*
		cases : 
			1/ transid in bettrans AND subtransid in bettransm => isMoved = 0 (not satisfied additional conditions of search)
			
			2/ transid in bettrans14, subtransid in bettransm14 => isMoved = 1
			3/ transid in bettrans14, subtransid in bettransm => isMoved = 1		
			4/ transid in bettrans, subtransid in bettransm14 => isMoved = 1
									
			5/ transid not in bettrans OR subtransid not in bettransm  => isMoved = 0 (not real ticket)
			6/ transid belong to match are going to be moved => isMoved = 1
		*/
		;WITH t_invalid AS
		(
			SELECT t.transid
				 , CASE
						WHEN m.transid IS NOT NULL
								THEN CAST(1 AS BIT) -- case 6
						WHEN b.transid IS NOT NULL
							 AND bm.transid IS NOT NULL
								THEN CAST(0 AS BIT) -- case 1
						WHEN b14.transid IS NOT NULL
							 OR bm14.transid IS NOT NULL
								THEN CAST(1 AS BIT) -- case 2 + 3 + 4				
						ELSE CAST(0 AS BIT) -- case 5 					
				   END AS isMoved
			FROM #tblTransIds t
				 LEFT JOIN bettrans b WITH(NOLOCK)
						ON t.transid = b.transid
						   AND b.bettype = 29 AND b.SiteDBGroupID = @SiteDBGroupID
				 LEFT JOIN bettransm bm WITH (NOLOCK)
						ON b.refno = bm.refno AND bm.SiteDBGroupID = b.SiteDBGroupID
						   AND bm.matchid = @MatchId
				 LEFT JOIN bettrans14 b14 WITH(NOLOCK)
						ON t.transid = b14.transid AND b14.SiteDBGroupID = @SiteDBGroupID
				 LEFT JOIN bettransm14 bm14 WITH(NOLOCK)
						ON ISNULL(b.refno, b14.refno) = bm14.refno AND bm14.SiteDBGroupID = @SiteDBGroupID
						   AND bm14.matchid = @MatchId	
				 LEFT JOIN @tmpTransIdMoveBet m
						ON t.transid = m.transid
			WHERE t.transid NOT IN (SELECT transid FROM #RecoverBet)
		)
		SELECT @InvalidTransIds = @InvalidTransIds +
								  CASE
									  WHEN isMoved = 0
											THEN CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + 
												 CAST(transid AS VARCHAR(50))
									  ELSE ''
								  END								  
			 , @MovedTransIds = @MovedTransIds +
								CASE
									WHEN isMoved = 1
											THEN CASE WHEN @MovedTransIds <> '' THEN ',' ELSE '' END + 
												 CAST(transid AS VARCHAR(50))
									ELSE ''
								END
		FROM t_invalid
	END		
	
	-- update Isdeposit
	UPDATE r 
		SET IsDeposit = 1
	FROM #RecoverBet r
	WHERE EXISTS (SELECT d.custid FROM CustDB.dbo.Dep_CustSuper d WITH(NOLOCK) WHERE d.custid = r.srecommend)

	------------------------------------------------------------------------------
	--1. Table invald/moved transid
	SELECT @InvalidTransIds AS InvalidTransIds
		  ,@MovedTransIds AS MovedTransIds

	--2. Table get tickets
	SELECT  r.Stake,
			r.AwayId,
			r.BetCheck,
			r.BetId,
			r.BetTeam,
			r.BetType,
			r.CurrencyCode,
			r.Hdp1,
			r.Hdp2,
			r.HomeId,
			r.IsLiveIndicator,
			r.LiveAwayScore,
			r.LiveHomeScore,
			r.Odds,
			r.OddsType,
			r.RefNo,
			r.SportType,
			r.Status,
			r.TransDate,
			r.TransDesc,
			r.TransId,
			r.UserName,
			r.WinLost,
			T.GroupName,
			r.showtime,
			r.LeagueId,
			r.matchcode,
			r.modds AS MasterOdds,
			r.SubStatus,
			r.SubTransId,
			r.SubBetCheck,
			r.SubBetTeam,
			r.SubBetType,
			r.SubHdp1,
			r.SubHdp2,
			r.SubOdds,
			r.SubTransdesc,
			@SiteDBGroupID AS SiteDBGroupID,
			VendorMatchId,
			MatchId
	FROM #RecoverBet r
	      CROSS APPLY (SELECT CASE 
								WHEN r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
										AND r.username <> '12EU'  
										AND r.mrecommend NOT IN (105181, 118473, 105183)  
										AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
									THEN 
										CASE WHEN r.IsDeposit = 0 THEN 'Credit'
												WHEN r.IsDeposit = 1 THEN 'Deposit'
												ELSE '' END
								ELSE '' END AS GroupName) AS T
	ORDER BY CASE
				WHEN T.GroupName = 'Credit'	 THEN 0
				WHEN T.GroupName = 'Deposit' THEN 1				
				ELSE 2				
			 END ASC
		
	DROP TABLE #RecoverBet
	DROP TABLE #tblTransIds
	SET NOCOUNT OFF		
END
GO