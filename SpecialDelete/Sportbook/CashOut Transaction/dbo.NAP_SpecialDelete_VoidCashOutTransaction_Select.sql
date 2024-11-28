/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_SpecialDelete_VoidCashOutTransaction_Select]
(
	@MatchId			INT				= 0
	,@Duration      	XML          	= NULL
	,@FilterBy			TINYINT 		= 0
	,@TransIds			VARCHAR(MAX)	= ''
)
AS
/*
    Created by: 20170323@Kent
	Task: Select Cash-out transaction for delete
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02

	Revisions:	
		- 20170403@Kent: Integrate Cash-out [Redmine:#72059]			
		- 20170417@Kent: Tune performance [Redmine:#72059]
		- 20190920@Charles: Add filter transdate when search by MatchId [120586]		
		- 20200930@Zane: TVS - Allow filter by Accept Time on Void Cash Out [Redmine:#142482]
		- 20210712@July: TVS - Modify the way to get move bet date [Redmine: #154974]
		- 20211213@Max: [TVS] Integrate new Cash Out model [Redmine: #165097]
		- 20220303@Max: [TVS] Update Virtual Setting when Cancel CO and some enhancements [Redmine: #169237]
		- 20220315@Max: Remove SABA of league name for China View sites [Redmine: #168651]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220727@Max: [TVS] Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20230420@July: [TVS] Update the data length of 'betfrom' column [Redmine: #187035]
		- 20230818@Max: [TVS] Cancel Cash Out Action - Search by BetID [Redmine: #186624]
		- 20240327@July: [TVS] Show Half Won - Half Lost on the bet list [Redmine: #202267]
		- 20241125@Lani: [TVS] Change join type and serverAlias [Redmine: #213451]

	Explanation's Param:
		@MatchId: <> 0 - by MatchId
				 = 0 - by BetId(s) 
		@FilterBy:	0 - by Trans time
				 	1 - by Accepted time
*/
BEGIN	
	SET NOCOUNT ON
	
	CREATE TABLE #SpecialDeleteBets (	
		BetId				BIGINT,
		TransId				BIGINT,
		BetType				SMALLINT,
		BetTeam				NVARCHAR(10),
		Stake				MONEY,
		Odds				SMALLMONEY,
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
		UserName			VARCHAR(30),		
		TransDate			DATETIME,		
		ExtraInfo			VARCHAR(1000),
		BetdaqId			BIGINT,
		custid				INT,
		recommend			INT,
		betfrom				NVARCHAR(4),		
		HomeId				INT,
		AwayId				INT,
		LeagueId			INT,
		SportTypeId			SMALLINT,
		IsNeutral			BIT,
		MatchCode			NVARCHAR(50),
		EventDate			DATETIME,
		statuswinlost		TINYINT,
		ActualStake			MONEY,
		MatchId				INT,
		modds				SMALLMONEY,
		SiteDBGroupID		SMALLINT				
	)
	
	DECLARE @SiteDBGroupID	SMALLINT
		,@InvalidTransIds	VARCHAR(MAX)	= '' 
		,@MovedTransIds		VARCHAR(MAX)	= ''

	SELECT @SiteDBGroupID = dbo.f_Get_SiteDBGroupID()

	CREATE TABLE #Durations (FromTransDate DATETIME, ToTransDate DATETIME)
	CREATE TABLE #tblTransIds (transid BIGINT)
	
   IF @MatchId <> 0
   BEGIN
	   -- Only parse xml @Durations if @Duration is not null and is not empty
		IF ISNULL(DATALENGTH(@Duration), 5) <> 5
		BEGIN 
			INSERT INTO #Durations
				   (FromTransDate,
					ToTransDate
				   )
				   SELECT x.value('@From', 'DATETIME') AS FromTransDate,
						  x.value('@To', 'DATETIME') AS ToTransDate
				   FROM @Duration.nodes('TransDates/TransDate') XmlData(x) OPTION(OPTIMIZE FOR(@Duration = NULL));
		END;

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
				UserName,						
				TransDate,						
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
				MatchCode,
				EventDate,
				statuswinlost,
				ActualStake,
				MatchId,
				modds,
				SiteDBGroupID
			)
		SELECT 
				sub.BetId,
				sub.TransId,
				sub.BetType,
				sub.BetTeam,
				sub.Stake,
				sub.Odds,
				sub.OddsType,
				sub.WinLost - sub.Actual_Stake AS WinLost,
				sub.Hdp1,
				sub.Hdp2,
				sub.Status,
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
				m.HomeId,
				m.AwayId,
				m.LeagueId,
				m.sporttype AS SportTypeId,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.MatchCode,
				m.EventDate,
				sub.statuswinlost,
				sub.actual_stake AS ActualStake,
				@MatchId,
				sub.modds,
				sub.SiteDBGroupID
		FROM	dbo.bettrans sub WITH(NOLOCK)	
			INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = sub.matchid
			INNER JOIN dbo.CashOutSelling c WITH (NOLOCK) ON c.TransID = sub.transid
		WHERE	sub.matchid = @MatchId 	
				AND sub.betdaqid = -2
				AND sub.statusID IN (103, 111, 112, 113)
				AND EXISTS (SELECT TOP (1) 1 FROM #Durations d
					WHERE 1 = CASE WHEN @FilterBy = 1 AND c.checktime BETWEEN d.FromTransDate AND d.ToTransDate THEN 1
								WHEN @FilterBy = 0 AND sub.transdate BETWEEN d.FromTransDate AND d.ToTransDate THEN 1
								ELSE 0 
								END)
				AND sub.SiteDBGroupID = @SiteDBGroupID
	END
	ELSE --Search by betid 
	BEGIN
		
		DECLARE @tmpTransIdMoveBet TABLE (Transid BIGINT) 
		DECLARE @MovebetDate	  DATETIME

		EXEC dbo.NAP_Admin_CheckingMoveBetDate @Movebetdate = @MovebetDate OUTPUT
	
		INSERT INTO #tblTransIds (transid)
		SELECT DISTINCT t.value
		FROM STRING_SPLIT(@TransIds, ',') t
		WHERE @TransIds <> ''

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
				UserName,						
				TransDate,						
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
				MatchCode,
				EventDate,
				statuswinlost,
				ActualStake,
				MatchId,
				modds,
				SiteDBGroupID
			)
		SELECT 
				sub.BetId,
				sub.TransId,
				sub.BetType,
				sub.BetTeam,
				sub.Stake,
				sub.Odds,
				sub.OddsType,
				sub.WinLost - sub.Actual_Stake AS WinLost,
				sub.Hdp1,
				sub.Hdp2,
				sub.Status,
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
				m.HomeId,
				m.AwayId,
				m.LeagueId,
				m.sporttype AS SportTypeId,
				ISNULL(m.IsNeutral, CONVERT(BIT, 0)) AS IsNeutral,
				m.MatchCode,
				m.EventDate,
				sub.statuswinlost,
				sub.actual_stake AS ActualStake,
				@MatchId,
				sub.modds,
				sub.SiteDBGroupID
		FROM #tblTransIds t
			INNER JOIN dbo.bettrans sub WITH(NOLOCK) ON t.transid = sub.TransId
			INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = sub.matchid
			INNER JOIN dbo.CashOutSelling c WITH (NOLOCK) ON c.TransID = sub.transid
		WHERE	sub.betdaqid = -2
				AND sub.statusID IN (103, 111, 112, 113)
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
	
	END

	SELECT @InvalidTransIds AS InvalidTransIds
			, @MovedTransIds AS MovedTransIds
	
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
			d.UserName,			
			d.TransDate,
			ci.site AS GroupName,
			d.ExtraInfo,
			d.BetdaqId,			
			d.HomeId,
			d.AwayId,
			d.LeagueId,
			d.SportTypeId,
			d.IsNeutral,
			d.MatchCode,
			d.statuswinlost,
			d.ActualStake,
			d.MatchId,
			d.modds AS MasterOdds,
			d.SiteDBGroupID
	FROM #SpecialDeleteBets d	
		 INNER JOIN CUSTDB.dbo.Customer AS ci WITH (NOLOCK) ON d.custid = ci.custid	
		 	
	ORDER BY ci.site ASC, d.TransId ASC							 						 
	
	DROP TABLE #SpecialDeleteBets
	DROP TABLE #Durations

	SET NOCOUNT OFF
END
GO
