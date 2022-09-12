/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverVSBetRadar_Sel] 
	@TicketType			VARCHAR(100),
	@Type				VARCHAR(100)	= NULL,
	@MatchId			INT				= 0,		
	@TransIds			VARCHAR(MAX)	= ''
AS
/*  
	Created by: Kent  
	Date: 20170607
	Task: 
	DB: DBTXN/bodb02   
	Original:NAP_SpecialDelete_RecoverVSBetRadar_Sel     

	Revisions:  		
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]			
		- 20180406@Helen: add filter by bettype for sport 181->185 to avoid the same value in table VSOutright (orid) and bettrans (oddsid) [Redmind:93183]
		- 20210712@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220910@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		
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
		RefNo			BIGINT,
		SportType		SMALLINT,
		Status			NVARCHAR(10),
		TransDate		DATETIME,
		TransDesc		NVARCHAR(1000),
		TransId			BIGINT,
		UserName		VARCHAR(30),
		WinLost			MONEY,
		IsDeposit		BIT,
		recommend		INT,
		mrecommend		INT,
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
		SubTransdesc	NVARCHAR(2000)		
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
	IF @TicketType = 'Single'	   	
	BEGIN
		--> VS Betradar, Inspired VS 180	
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
				IsDeposit,
				recommend,
				mrecommend,
				CustId,
				showtime,
				LeagueId,
				matchcode,
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
		SELECT  z.Stake,
				m.AwayId,
				z.BetCheck,
				b.BetId,
				z.BetTeam,
				z.BetType,
				b.CurrencyName AS CurrencyCode,
				z.Hdp1,
				z.Hdp2,
				m.HomeId,
				z.liveindicator AS IsLiveIndicator,
				z.LiveAwayScore,
				z.LiveHomeScore,
				z.Odds,
				b.OddsType,
				z.RefNo,
				m.SportType,
				z.Status,
				b.TransDate,
				b.TransDesc,
				z.TransId,
				b.UserName,
				z.winlost - b.actual_stake AS WinLost,
				CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
				b.recommend,
				b.mrecommend,
				b.CustId,
				ISNULL(CONVERT(NVARCHAR(20), m.kickofftime, 113), '') AS showtime,
				m.leagueid,
				NULL AS matchcode,
				b.modds,
				m.EventDate,
				NULL AS SubStatus,
				NULL AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubTransdesc
		FROM dbo.zzzbettrans z WITH (NOLOCK)					 
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype
			 INNER JOIN dbo.match m WITH(NOLOCK)
					 ON m.matchid = b.matchid
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
		  AND z.winlostdate >= @before_yesterday
		  AND (
				m.sporttype BETWEEN 190 AND 199 -- VS Betradar
				OR m.sporttype IN (180, 186) -- Inspired VS 
			  )
		  AND z.bettype NOT IN (2799)		  		
		  AND z.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = z.SiteDBGroupID

		--> Inspired VS 181
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
				IsDeposit,
				recommend,
				mrecommend,
				CustId,
				showtime,
				LeagueId,
				matchcode,
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
		SELECT  z.Stake,
				0 AS AwayId,
				z.BetCheck,
				b.BetId,
				z.BetTeam,
				z.BetType,
				b.CurrencyName AS CurrencyCode,
				z.Hdp1,
				z.Hdp2,
				o.RacerID AS HomeId,
				z.liveindicator AS IsLiveIndicator,
				z.LiveAwayScore,
				z.LiveHomeScore,
				z.Odds,
				b.OddsType,
				z.RefNo,
				r.SportType,
				z.Status,
				b.TransDate,
				b.TransDesc,
				z.TransId,
				b.UserName,
				z.winlost - b.actual_stake AS WinLost,
				CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
				b.recommend,
				b.mrecommend,
				b.CustId,
				ISNULL(CONVERT(NVARCHAR(20), r.EventTime, 113), '') AS showtime,
				r.LeagueID,
				CONVERT(NVARCHAR(50), o.RacerNum) AS matchcode,
				b.modds,
				o.EventDate,
				NULL AS SubStatus,
				NULL AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubTransdesc
		FROM dbo.zzzbettrans z WITH (NOLOCK)					 
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype
			 INNER JOIN dbo.VSOutright o WITH (NOLOCK) 
					 ON b.oddsid = o.Orid
			 INNER JOIN dbo.VSRaceInfo r WITH (NOLOCK) 
					 ON r.EventID = o.EventID
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
		  AND z.winlostdate >= @before_yesterday
		  AND r.sporttype BETWEEN 181 AND 185 -- Inspired VS 181		  				  			  				
		  AND b.bettype IN (1231,1232,1233,1237,1238)		
		  AND z.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = z.SiteDBGroupID

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
	
	--> search by @TransIds
	IF @TicketType = 'Mix Parlay' AND @Type = 'Main'
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
				IsDeposit,
				recommend,
				mrecommend,
				CustId,
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
		SELECT  z.Stake,
				NULL AS AwayId,
				z.BetCheck,
				b.BetId,
				z.BetTeam,
				z.BetType,
				b.CurrencyName AS CurrencyCode,
				z.Hdp1,
				z.Hdp2,
				NULL AS HomeId,
				z.liveindicator AS IsLiveIndicator,
				z.LiveAwayScore,
				z.LiveHomeScore,
				z.Odds,
				b.OddsType,
				z.RefNo,
				NULL AS SportType,
				z.Status,
				b.TransDate,
				b.TransDesc,
				z.TransId,
				b.UserName,
				z.winlost - b.actual_stake AS WinLost,
				CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
				b.recommend,
				b.mrecommend,
				b.CustId,
				b.modds,				
				b.winlostdate AS EventDate,
				NULL AS SubStatus,
				NULL AS SubTransId,
				NULL AS SubBetCheck,
				NULL AS SubBetTeam,
				NULL AS SubBetType,
				NULL AS SubHdp1,
				NULL AS SubHdp2,
				NULL AS SubOdds,
				NULL AS SubTransdesc
		FROM dbo.zzzbettrans z WITH (NOLOCK)					 
			 INNER JOIN dbo.bettrans b WITH (NOLOCK)
					 ON	z.transid = b.transid
						AND z.custid = b.custid
						AND z.matchid = b.matchid					
						AND z.bettype = b.bettype			 
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
		  AND z.winlostdate >= @before_yesterday
		  AND z.matchid = 2799
		  AND z.bettype = 2799		  
		  AND z.SiteDBGroupID = @SiteDBGroupID AND b.SiteDBGroupID = z.SiteDBGroupID

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
									 WHERE b14.transid = t.transid AND b14.SiteDBGroupID = @SiteDBGroupID
									 UNION ALL
									 SELECT TOP 1 1 
									 FROM @tmpTransIdMoveBet m
									 WHERE m.transid = t.transid)
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
				IsDeposit,
				recommend,
				mrecommend,
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
				CASE WHEN b.srecommend IN (SELECT custid from custDB.dbo.Dep_CustSuper with(NOLOCK)) then 1 ELSE 0 END as IsDeposit,
				b.recommend,
				b.mrecommend,
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
			 INNER JOIN dbo.match m WITH(NOLOCK)
					 ON	m.matchid = bm.matchid
		WHERE b.transid IN (SELECT transid FROM #tblTransIds)
		  AND bm.matchid = @MatchId	
		  AND bm.winlostdate >= @before_yesterday
		  AND m.sporttype BETWEEN 190 AND 199
		  AND b.bettype = 2799
		  AND b.matchid = 2799
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
			r.modds,
			r.SubStatus,
			r.SubTransId,
			r.SubBetCheck,
			r.SubBetTeam,
			r.SubBetType,
			r.SubHdp1,
			r.SubHdp2,
			r.SubOdds,
			r.SubTransdesc
	FROM #RecoverBet r
	     CROSS APPLY (SELECT CASE 
								WHEN r.IsDeposit = 0  
									 AND r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
									 AND r.username <> '12EU'  
									 AND r.mrecommend NOT IN (105181, 118473, 105183)  
									 AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Credit'
								WHEN r.IsDeposit = 1  
									 AND r.custid NOT IN (SELECT CustID FROM [f_GetBetDaqCustomer] (1))    
									 AND r.username <> '12EU'  
									 AND r.mrecommend NOT IN (105181, 118473, 105183) 
									 AND r.recommend NOT IN (11196380, 13423967) -- Foobet, 1E
											THEN 'Deposit'																			
								ELSE ''							
							 END AS GroupName) AS T
	ORDER BY CASE
				WHEN T.GroupName = 'Credit'	 THEN 0
				WHEN T.GroupName = 'Deposit' THEN 1				
				ELSE 2				
			 END ASC
			 
	SET NOCOUNT OFF		
END
GO