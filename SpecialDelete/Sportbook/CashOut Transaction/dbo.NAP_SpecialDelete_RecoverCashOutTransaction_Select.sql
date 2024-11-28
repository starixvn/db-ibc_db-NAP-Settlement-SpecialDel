 /*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_RecoverCashOutTransaction_Select]
(
	@TransIds			VARCHAR(MAX)	= ''
)
AS
/*
    Created by: 20170323@Kent
	Task: Select CashOut transaction for recover
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions:	
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]	
		- 20210712@July: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210812@July: Add metadata [Redmine: #157970] 
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20241125@Lani: [TVS] Change join type on 'recommend' and 'custid' column, change serverAlias [Redmine: #213451]

	Explanation's Param:
		@Option: 0 - by MatchId - removed
				 1 - by BetId(s)


*/
BEGIN	
	SET NOCOUNT ON

	DECLARE @InvalidTransIds	VARCHAR(MAX)	= '' 
		,@MovedTransIds		VARCHAR(MAX)	= '' 	
		,@SiteDBGroupID		SMALLINT

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()
	
	CREATE TABLE #SpecialDeleteBets (	
		BetId				BIGINT,
		TransId				BIGINT,
		BetType				SMALLINT,
		BetTeam				NVARCHAR(10),
		Stake				MONEY,
		Odds				SMALLMONEY,
		modds				SMALLMONEY,
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
		betfrom				NVARCHAR(4),		
		WinLost				MONEY,
		Status				NVARCHAR(10),		
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME	,
		ActualStake			MONEY,
		SiteDBGroupID		SMALLINT
	)
	
	CREATE TABLE #tblTransIds (transid BIGINT)
	CREATE TABLE #tmpKeyId (KeyId INT)

	DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT) 
	DECLARE @MovebetDate	  DATETIME

	EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT
	
	INSERT INTO #tblTransIds (transid)
	SELECT	t.value
	FROM STRING_SPLIT(@TransIds, ',') t			

	INSERT INTO #tmpKeyId (KeyId)
	SELECT MAX(z.keyid)
	FROM zzzbettrans z WITH (NOLOCK)
	WHERE	z.transid IN (SELECT transid FROM #tblTransIds)							
		AND z.comstatus = 'CO'
	GROUP BY z.transid
	
	INSERT INTO #SpecialDeleteBets(
					BetId,
					TransId,
					BetType,
					BetTeam,
					Stake,
					Odds,
					modds,
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
					EventDate,
					ActualStake,
					SiteDBGroupID
				)
	SELECT 
			sub.BetId,
			sub.TransId,
			sub.BetType,
			sub.BetTeam,
			sub.Stake,
			sub.Odds,
			sub.modds,
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
			m.EventDate,
			sub.actual_stake AS ActualStake,
			sub.SiteDBGroupID
	FROM	dbo.zzzbettrans z WITH(NOLOCK)
		INNER JOIN #tmpKeyId t ON t.KeyId = z.keyid
		INNER JOIN dbo.bettrans sub WITH(NOLOCK)
			ON	z.transid = sub.transid
				AND z.bettype = sub.bettype
				AND z.matchid = sub.matchid	
				AND z.custid = sub.custid			
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON m.matchid = z.matchid
	WHERE	sub.betdaqid = -1
		AND sub.SiteDBGroupID = @SiteDBGroupID
				
	IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE EventDate <= @MovebetDate)
	BEGIN
		DELETE 
		FROM #SpecialDeleteBets
			OUTPUT	DELETED.TransId
			INTO @tmpTransIdMoveBet (TransId)
		WHERE EventDate <= @MovebetDate
	END	
	
	-- invalid trans		
	SELECT @InvalidTransIds = '', @MovedTransIds = ''
	;WITH t_invalid AS
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

	SELECT @InvalidTransIds AS InvalidTransIds
		, @MovedTransIds AS MovedTransIds
					
	SELECT	d.BetId,
			d.TransId,
			d.BetType,
			d.BetTeam,
			d.Stake,
			d.Odds,
			d.modds AS MasterOdds,
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
			ci.site AS GroupName,
			d.ExtraInfo,
			d.BetdaqId,			
			d.WinLost,
			d.Status,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode,
			d.ActualStake,
			d.SiteDBGroupID
	FROM #SpecialDeleteBets d
	     INNER JOIN CUSTDB.dbo.Customer AS ci WITH (NOLOCK) ON ci.custid = d.custid
		 LEFT JOIN CUSTDB.dbo.Customer c WITH (NOLOCK)
				 ON d.recommend = c.custid		 	
	ORDER BY c.site ASC, d.TransId ASC				
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblTransIds
	DROP TABLE #tmpKeyId
	
	SET NOCOUNT OFF
END
GO