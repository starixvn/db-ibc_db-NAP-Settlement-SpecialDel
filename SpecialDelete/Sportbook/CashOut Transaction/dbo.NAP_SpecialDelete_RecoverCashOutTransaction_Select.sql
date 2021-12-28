 /*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverCashOutTransaction_Select]
(
	 @Option			BIT				= 0
	,@MatchId			INT				= 0
	,@FromTransId		BIGINT			= 0
	,@ToTransId			BIGINT			= 0
	,@TransIds			VARCHAR(MAX)	= ''
	,@InvalidTransIds	VARCHAR(MAX)	= '' OUTPUT
	,@MovedTransIds		VARCHAR(MAX)	= '' OUTPUT	
)
AS
/*
    Created by: Kent
	Date: 20170323
	Original: 
	Task: Select CashOut transaction for recover
	DB: DBTXN/BODB02

	Revisions:	
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]	
		- 20210712@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210812@July: Add metadata [Redmine: #157970] 
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]

	Explanation's Param:
		@Option: 0 - by MatchId
				 1 - by BetId(s)


*/
BEGIN	
	SET NOCOUNT ON
	
	CREATE TABLE #SpecialDeleteBets (	
		BetId				BIGINT,
		TransId				BIGINT,
		BetType				SMALLINT,
		BetTeam				NVARCHAR(10),
		Stake				MONEY,
		Odds				MONEY,
		OddsType			INT,		
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,		
		IsLiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,		
		RefNo				BIGINT,				
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		UserName			VARCHAR(30),		
		TransDate			DATETIME,		
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,
		betfrom				NVARCHAR(1),		
		WinLost				MONEY,
		Status				NVARCHAR(10),		
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME		
	)
	
	CREATE TABLE #tblTransIds (transid BIGINT)
	CREATE TABLE #tmpKeyId (KeyId INT)

	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT) 
	DECLARE @MovebetDate	  DATETIME

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT
	
	IF @Option = 0
	BEGIN
		INSERT INTO #tmpKeyId (KeyId)
		SELECT MAX(z.keyid)
		FROM zzzbettrans z WITH (NOLOCK)
		WHERE z.transid BETWEEN @FromTransId AND @ToTransId
			AND z.comstatus = 'CO'
		GROUP BY z.transid
	END
	ELSE IF @Option = 1
	BEGIN
		INSERT INTO #tblTransIds (transid)
		SELECT	t.val
		FROM dbo.f_SplitString(@TransIds, ',') t			
		OPTION (maxrecursion 0)

		INSERT INTO #tmpKeyId (KeyId)
		SELECT MAX(z.keyid)
		FROM zzzbettrans z WITH (NOLOCK)
		WHERE	z.transid IN (SELECT transid FROM #tblTransIds)							
			AND z.comstatus = 'CO'
		GROUP BY z.transid
	END
	
	INSERT INTO #SpecialDeleteBets(
					BetId,
					TransId,
					BetType,
					BetTeam,
					Stake,
					Odds,
					OddsType,
					Hdp1,
					Hdp2,
					IsLiveIndicator,
					LiveHomeScore,
					LiveAwayScore,
					RefNo,					
					BetCheck,
					TransDesc,
					UserName,						
					TransDate,						
					ExtraInfo,
					BetdaqId,
					custid,
					recommend,
					betfrom,
					WinLost,
					Status,
					HomeId,
					AwayId,
					LeagueId,
					SportTypeId,
					IsNeutral,
					MatchCode,
					EventDate
				)
	SELECT 
			sub.BetId,
			sub.TransId,
			sub.BetType,
			sub.BetTeam,
			sub.Stake,
			sub.Odds,
			sub.OddsType,				
			sub.Hdp1,
			sub.Hdp2,				
			sub.liveindicator AS IsLiveIndicator,
			sub.LiveHomeScore,
			sub.LiveAwayScore,				
			sub.RefNo,							
			sub.BetCheck,
			sub.TransDesc,
			sub.UserName,				
			sub.TransDate,				
			sub.ExtraInfo,
			sub.BetdaqId,
			sub.custid,
			sub.recommend,
			sub.betfrom,				
			z.winlost - sub.actual_stake as Winlost,
			z.Status,				
			m.HomeId,
			m.AwayId,
			m.LeagueId,
			m.sporttype AS SportTypeId,
			ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
			m.MatchCode,
			m.EventDate
	FROM	dbo.zzzbettrans z WITH(NOLOCK)
		INNER JOIN #tmpKeyId t ON t.KeyId = z.keyid
		INNER JOIN dbo.bettrans sub WITH(NOLOCK)
			ON	z.transid = sub.transid
				AND z.bettype = sub.bettype
				AND z.matchid = sub.matchid	
				AND z.custid = sub.custid			
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON m.matchid = z.matchid
	WHERE	sub.matchid = CASE WHEN @Option = 0 THEN @MatchId ELSE sub.matchid END
		AND sub.betdaqid = -1
				
	IF (@Option = 1)
	BEGIN
		IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE EventDate <= @MovebetDate)
		BEGIN
			DELETE 
			FROM #SpecialDeleteBets
				OUTPUT	DELETED.TransId
				INTO @tmpTransIdMoveBet (TransId)
			WHERE EventDate <= @MovebetDate
		END	
	END						
					
	SELECT	d.BetId,
			d.TransId,
			d.BetType,
			d.BetTeam,
			d.Stake,
			d.Odds,
			d.OddsType,			
			d.Hdp1,
			d.Hdp2,			
			d.IsLiveIndicator,
			d.LiveHomeScore,
			d.LiveAwayScore,			
			d.RefNo,						
			d.BetCheck,
			d.TransDesc,
			d.UserName,			
			d.TransDate,
			c.site AS GroupName,
			d.ExtraInfo,
			d.BetdaqId,			
			d.WinLost,
			d.Status,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode
	FROM #SpecialDeleteBets d
		 INNER JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
				 ON d.recommend = c.custid		 	
	ORDER BY c.site ASC, d.TransId ASC				
	
	-- invalid trans		
	SELECT @InvalidTransIds = '', @MovedTransIds = ''
	IF (@Option = 1)	
		WITH t_invalid AS
		(
			SELECT	t.transid
					,CASE 
						WHEN EXISTS (
									 SELECT TOP 1 1 
									 FROM dbo.bettrans14 b14 WITH(NOLOCK) 
									 WHERE b14.transid = t.transid

									 UNION ALL
									 SELECT TOP 1 1 
									 FROM @tmpTransIdMoveBet m
									 WHERE m.transid = t.transid)
							THEN 1
						ELSE 0 
					 END AS isMoved					
			FROM	#tblTransIds t
			WHERE	t.transid NOT IN (SELECT transid FROM #SpecialDeleteBets)
		)
		SELECT @InvalidTransIds = @InvalidTransIds +
								  CASE
									  WHEN isMoved = 0
											THEN CASE WHEN @InvalidTransIds <> '' THEN ',' ELSE '' END + 
												 CAST(transid AS VARCHAR(100))
									  ELSE ''
								  END								  
			 , @MovedTransIds = @MovedTransIds +
								CASE
									WHEN isMoved = 1
											THEN CASE WHEN @MovedTransIds <> '' THEN ',' ELSE '' END + 
												 CAST(transid AS VARCHAR(100))
									ELSE ''
								END
		FROM t_invalid
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblTransIds
	DROP TABLE #tmpKeyId
	
	SET NOCOUNT OFF
END
GO