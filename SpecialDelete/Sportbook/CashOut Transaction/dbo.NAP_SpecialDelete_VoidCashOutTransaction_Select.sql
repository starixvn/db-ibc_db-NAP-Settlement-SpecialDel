USE [bodb02]
GO
/****** Object:  StoredProcedure [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Select]    Script Date: 01/25/2016 10:22:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Select]
	@Option			BIT				= 0
	,@MatchId		INT
	,@FromTransId	BIGINT			= 0
	,@ToTransId		BIGINT			= 0
	,@TransIds		VARCHAR(MAX)	= ''
	
	,@InvalidTransIds VARCHAR(MAX)  = '' OUTPUT
	,@MovedTransIds	  VARCHAR(MAX)  = '' OUTPUT
AS
/*
    Created by: Kent
	Date: 20170323
	Original: 
	Task: Select Cash-out transaction for delete
	DB: DBTXN/BODB02

	Revisions:	
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]	
		
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
		WinLost				MONEY,
		Hdp1				SMALLMONEY,
		Hdp2				SMALLMONEY,
		Status				NVARCHAR(10),
		IsLiveIndicator		BIT,
		LiveHomeScore		SMALLINT,
		LiveAwayScore		SMALLINT,		
		RefNo				BIGINT,				
		BetCheck			NVARCHAR(50),
		TransDesc			NVARCHAR(1000),
		MainStatusId		TINYINT,
		UserName			VARCHAR(30),		
		TransDate			DATETIME,		
		OriginalBetType		SMALLINT,
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,
		betfrom				NVARCHAR(1),		
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50)		
	)
	
	CREATE TABLE #tblTransIds (transid BIGINT)
	
	IF (@Option = 0)	
		INSERT INTO #SpecialDeleteBets(
						BetId,
						TransId,
						BetType,
						BetTeam,
						Stake,
						Odds,
						OddsType,
						WinLost,
						Hdp1,
						Hdp2,
						Status,
						IsLiveIndicator,
						LiveHomeScore,
						LiveAwayScore,						
						RefNo,						
						BetCheck,
						TransDesc,
						MainStatusId,
						UserName,						
						TransDate,						
						OriginalBetType,
						ExtraInfo,
						BetdaqId,
						custid,
						recommend,
						betfrom,						
						HomeId,
						AwayId,
						LeagueId,
						SportTypeId,
						IsNeutral,
						MatchCode)
		SELECT 
				main.BetId,
				sub.TransId,
				sub.BetType,
				main.BetTeam,
				sub.Stake,
				main.Odds,
				main.OddsType,
				sub.WinLost - sub.Actual_Stake AS WinLost,
				main.Hdp1,
				main.Hdp2,
				sub.Status,
				main.liveindicator AS IsLiveIndicator,
				main.LiveHomeScore,
				main.LiveAwayScore,				
				sub.RefNo,				
				main.BetCheck,
                main.TransDesc,
				main.statusID AS MainStatusId,
				sub.UserName,				
				sub.TransDate,				
				main.bettype AS OriginalBetType,
				sub.ExtraInfo,
				sub.BetdaqId,
				sub.custid,
				main.recommend,
				main.betfrom,				
				m.HomeId,
				m.AwayId,
				m.LeagueId,
				m.sporttype AS SportTypeId,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.MatchCode
		FROM	dbo.bettrans sub WITH(NOLOCK)
			INNER JOIN dbo.bettrans main WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND main.matchid = sub.matchid
					AND main.custid = sub.custid		
			INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = sub.matchid
		WHERE	sub.matchid = @MatchId 
				AND sub.transid BETWEEN @FromTransId AND @ToTransId				
				AND sub.bettype = 911 -- SOLD tickets
				AND sub.statusID IN (103, 111, 112, 113)
				AND main.statusID IN (0, 103, 111, 112, 113) -- unsettled or refunded, DRAW, WON, LOSE
				AND main.betdaqid = 0
				AND charindex ('p25',main.extrainfo)> 0
	ELSE IF (@Option = 1)
	BEGIN
		INSERT INTO #tblTransIds (transid)
		SELECT	t.val
		FROM dbo.f_SplitString(@TransIds, ',') t			
		OPTION (maxrecursion 0)
		
		INSERT INTO #SpecialDeleteBets(
						BetId,
						TransId,
						BetType,
						BetTeam,
						Stake,
						Odds,
						OddsType,
						WinLost,
						Hdp1,
						Hdp2,
						Status,
						IsLiveIndicator,
						LiveHomeScore,
						LiveAwayScore,						
						RefNo,						
						BetCheck,
						TransDesc,
						MainStatusId,
						UserName,						
						TransDate,						
						OriginalBetType,
						ExtraInfo,
						BetdaqId,
						custid,
						recommend,
						betfrom,						
						HomeId,
						AwayId,
						LeagueId,
						SportTypeId,
						IsNeutral,
						MatchCode)
		SELECT 
				main.BetId,
				sub.TransId,
				sub.BetType,
				main.BetTeam,
				sub.Stake,
				main.Odds,
				main.OddsType,
				sub.WinLost - sub.Actual_Stake AS WinLost,
				main.Hdp1,
				main.Hdp2,
				sub.Status,
				main.liveindicator AS IsLiveIndicator,
				main.LiveHomeScore,
				main.LiveAwayScore,				
				sub.RefNo,				
				main.BetCheck,
                main.TransDesc,
				main.statusID AS MainStatusId,
				sub.UserName,				
				sub.TransDate,				
				main.bettype AS OriginalBetType,
				sub.ExtraInfo,
				sub.BetdaqId,
				sub.custid,
				main.recommend,
				main.betfrom,				
				m.HomeId,
				m.AwayId,
				m.LeagueId,
				m.sporttype AS SportTypeId,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.MatchCode
		FROM	dbo.bettrans sub WITH(NOLOCK)
			INNER JOIN dbo.bettrans main WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND main.matchid = sub.matchid	
					AND main.custid = sub.custid	
			INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = sub.matchid
		WHERE	sub.transid IN (SELECT transid FROM #tblTransIds)				
				AND sub.bettype = 911 -- SOLD tickets
				AND sub.statusID IN (103, 111, 112, 113)
				AND main.statusID IN (0, 103, 111, 112, 113) -- unsettled or refunded, DRAW, WON, LOSE
				AND main.betdaqid = 0
				AND charindex ('p25',main.extrainfo)> 0
	END				
	
	SELECT	d.BetId,
			d.TransId,
			d.BetType,
			d.BetTeam,
			d.Stake,
			d.Odds,
			d.OddsType,
			d.WinLost,
			d.Hdp1,
			d.Hdp2,
			d.Status,
			d.IsLiveIndicator,
			d.LiveHomeScore,
			d.LiveAwayScore,			
			d.RefNo,						
			d.BetCheck,
			d.TransDesc,
			d.MainStatusId,
			d.UserName,			
			d.TransDate,
			c.site AS GroupName,
			d.OriginalBetType,
			d.ExtraInfo,
			d.BetdaqId,			
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
						WHEN EXISTS (SELECT TOP 1 1 
									 FROM dbo.bettrans14 b14 WITH(NOLOCK) 
									 WHERE b14.transid = t.transid
									   AND b14.bettype = 911) 
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
	
	SET NOCOUNT OFF
END



GO
GRANT EXECUTE ON [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Select] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Select] TO [vnteam] AS [dbo]