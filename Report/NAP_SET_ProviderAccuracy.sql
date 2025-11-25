/*<info serverAlias="DBTP-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/ 
ALTER PROCEDURE NAP_SET_ProviderAccuracy
	@date DATE --the date wanna to export data, YYYY-MM-DD
AS
/*
	Created by: 20251121@Louisa
	Task: Provider Accuracy  

	Revisions:
		- 20251121@Louisa: Created [Redmine:#244547]

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @TotalResult DECIMAL
	
	DECLARE @columns		NVARCHAR(MAX) 
			,@ReplaceColumn NVARCHAR(MAX) 
			,@sql			NVARCHAR(MAX);

	CREATE TABLE #tmp_Matchid (MatchID INT, eventdate DATE, SportType SMALLINT, SportName NVARCHAR(100), leaguename  NVARCHAR(1000),LeagueGroupName NVARCHAR(400), HomeName NVARCHAR(200), AwayName  NVARCHAR(200) )
	CREATE TABLE #tmp_Settle (MatchID INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), SportType SMALLINT, Score VARCHAR(100), ResourceName VARCHAR(200), OtherInfo VARCHAR(100)  )
	CREATE TABLE #tmp_ResultProvider ( SourceID INT, MatchId INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ProviderName VARCHAR(50), Score VARCHAR(100) )	
	
	CREATE TABLE #tmp_ProviderInfo (SourceID INT, SourceName VARCHAR(50) )
	
	DECLARE @tmpResourceName TABLE ( Sporttype SMALLINT, ResourceFormat VARCHAR(50), ResourceName VARCHAR(200) )
	INSERT INTO @tmpResourceName (Sporttype, ResourceFormat,ResourceName)
			  SELECT 2	,'00'	,'Full Time' 			
	UNION ALL SELECT 2	,'01'	,'First Half'	
	UNION ALL SELECT 2	,'02'	,'Second Half'	
	UNION ALL SELECT 2	,'OT'	,'Over Time'			
	UNION ALL SELECT 2	,'Q1'	,'Quarter 1'			
	UNION ALL SELECT 2	,'Q2'	,'Quarter 2'			
	UNION ALL SELECT 2	,'Q3'	,'Quarter 3'			
	UNION ALL SELECT 2	,'Q4'	,'Quarter 4'	
	UNION ALL SELECT 2	,'604'	,'Which Team To Score The First Basket'			
	UNION ALL SELECT 2	,'605'	,'Which Team To Score The Last Basket'			
	UNION ALL SELECT 2	,'606'	,'1H Race To @X Points'			
	UNION ALL SELECT 2	,'607'	,'2H Race To @X Points'			
	UNION ALL SELECT 2	,'613'	,'Quarter @X Race To @Y Points'			
	UNION ALL SELECT 2	,'617'	,'Quarter @X Which Team To Score The Last Basket'	
	UNION ALL SELECT 2	,'653'	,'Player Points'			
	UNION ALL SELECT 2	,'656'	,'Player Assists'			
	UNION ALL SELECT 2	,'659'	,'Player Rebounds-Assists'			
	UNION ALL SELECT 2	,'662'	,'Player 3PT FG'			
	UNION ALL SELECT 2	,'665'	,'Player Blocks'			
	UNION ALL SELECT 2	,'667'	,'Player Steals'		
	UNION ALL SELECT 2	,'669'	,'Player Points-Rebounds-Assists'			
	UNION ALL SELECT 2	,'671'	,'Player Rebounds-Assists'			
	UNION ALL SELECT 2	,'673'	,'Player Points-Rebounds'			
	UNION ALL SELECT 2	,'674'	,'Player Steals-Blocks'	
	UNION ALL SELECT 2	,'675'  ,'Player Performance'
	UNION ALL SELECT 2	,'676'  ,'Player Performance'
	UNION ALL SELECT 2	,'678'  ,'Player Performance'
	UNION ALL SELECT 2	,'677'	,'Player Double Double'			
	UNION ALL SELECT 2	,'679'	,'Player Triple Double'			
	UNION ALL SELECT 2	,'680'	,'Most Points Scored'			
	UNION ALL SELECT 2	,'681'	,'Most Rebounds'			
	UNION ALL SELECT 2	,'682'	,'Most Steals'			
	UNION ALL SELECT 2	,'683'	,'Most Assists'			
	UNION ALL SELECT 2	,'684'	,'Most 3-Point Shots Scored'			

	--------------------------------------------------------------------------------
	INSERT INTO #tmp_Matchid (MatchID, eventdate, sporttype, SportName, leaguename,LeagueGroupName, HomeName, AwayName)
	SELECT m.matchid, m.eventdate , m.SportType, s.SportName, l.leaguename,lg.GroupName AS LeagueGroupName, home.teamname AS HomeName, away.teamname AS AwayName 
	FROM match m WITH(NOLOCK)
		INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
		INNER JOIN league l WITH(NOLOCK) ON m.leagueid = l.leagueid
		INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
		INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
		INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
	WHERE m.sporttype = 2
	AND m.eventdate = @date
	AND m.eventstatus = 'completed'
	AND l.isTest = 0
	AND l.LeagueGroupID <>  122

	INSERT INTO #tmp_Settle (sporttype,MatchID, ResourceID, HomeValue, AwayValue, Score, OtherInfo )
	SELECT m.sporttype, r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
			,CASE	WHEN ISNULL(r.HomeValue,'') = '' AND ISNULL(r.AwayValue,'') = '' THEN ''
					WHEN ISNULL(r.AwayValue,'') = '' THEN r.HomeValue
					ELSE ISNULL(r.HomeValue,'') + '-' + ISNULL(r.AwayValue,'')
				END AS Score
			,PARSENAME(REPLACE(r.OtherInfo, ',', '.'), 2)  ---- PlayerId
	FROM ResultDetail r WITH(NOLOCK)
		INNER JOIN #tmp_Matchid m ON r.MatchId = m.MatchID
	WHERE r.ResultStatusID IN (2, 5)
		AND 1 = CASE WHEN ResourceId = 'OT' AND ISNULL(HomeValue,'') = '' THEN 0 --Auto payout always settle null for this result
					WHEN ResourceId = '02' THEN 0 ---user don't know this data
					ELSE 1
					END
	UPDATE r
	SET ResourceName = CASE WHEN rn.ResourceFormat IN ('606', '607') THEN REPLACE( rn.ResourceName, '@X',RIGHT(r.ResourceID,2))
							  WHEN rn.ResourceFormat IN ('613', '617') THEN REPLACE(REPLACE( rn.ResourceName, '@X',SUBSTRING(r.ResourceID,4,2)), '@Y', RIGHT(r.ResourceID,2))
							  WHEN rn.ResourceName LIKE 'Player%' THEN REPLACE(rn.ResourceName, 'Player', t.teamname)
							  ELSE rn.ResourceName
				  END
	FROM  #tmp_Settle r 
		INNER JOIN  @tmpResourceName rn ON r.ResourceId LIKE rn.ResourceFormat +'%'
		LEFT JOIN team t WITH(NOLOCK) on r.OtherInfo = t.teamid

	INSERT INTO #tmp_ProviderInfo ( SourceID, SourceName)
	SELECT SourceID, SourceName
	FROM DBPRO.bodb02.dbo.ProviderInfo p WITH(NOLOCK)
	WHERE SourceID < 1001

	;WITH cte_ResultProvider ( SourceId, MatchId, ResourceID, HomeValue, AwayValue, rk) AS
	(
		SELECT pr.SourceId, pr.matchid, pr.ResourceId, pr.HomeValue, pr.AwayValue
				,ROW_NUMBER() OVER( PARTITION BY pr.SourceId, pr.matchid, pr.ResourceId ORDER BY pr.ProviderExternalID DESC ) AS rk
		FROM ProviderExternalResultDetail pr WITH(NOLOCK)
			INNER JOIN	#tmp_Matchid m  
				ON pr.matchid = m.matchid 
		WHERE pr.SourceId < 1001
			AND pr.SourceID NOT IN ( 97,98,99,100)
			AND pr.IsLive = 0
	)
  
	INSERT INTO #tmp_ResultProvider ( MatchId, SourceId, ResourceID, HomeValue, AwayValue, ProviderName, Score)
	SELECT  r.MatchId, r.SourceId, ResourceID, HomeValue, AwayValue, p.SourceName
			,CASE	WHEN ISNULL(r.HomeValue,'') = '' AND ISNULL(r.AwayValue,'') = '' THEN ''
					WHEN ISNULL(r.AwayValue,'') = '' THEN r.HomeValue
					ELSE ISNULL(r.HomeValue,'') + '-' + ISNULL(r.AwayValue,'')
				END AS Score
	FROM cte_ResultProvider r
		INNER JOIN #tmp_ProviderInfo p ON r.SourceId = p.SourceID
	WHERE rk = 1

	SELECT @TotalResult =  (SELECT COUNT(1) FROM #tmp_Settle)

	----Send email
	SELECT	@columns =isnull(@columns + ',', '') + quotename(ProviderName)
	FROM	(	SELECT		DISTINCT ProviderName
				FROM		#tmp_ResultProvider pr
			) AS s;

	SELECT	@ReplaceColumn = ISNULL(@ReplaceColumn + ',','')  + 'ISNULL(' + quotename(ProviderName)+ ', ''No Data'') AS ' +quotename(ProviderName)
	FROM	(	SELECT		DISTINCT ProviderName
				FROM		#tmp_ResultProvider pr
			) AS s;
 
	SET @sql=N'
	SELECT MatchID, EventDate, SportName, LeagueName, LeagueGroupName, HomeName, AwayName,
			ResourceID, ResourceName, Settled,' + @ReplaceColumn 
	+ '
	FROM
	(
	  SELECT  r.MatchID, m.eventdate, m.SportName, m.leaguename, m.LeagueGroupName, m.HomeName, m.AwayName
			, pr.ProviderName, r.ResourceID, r.ResourceName, r.Score AS [Settled], pr.Score
	   FROM #tmp_Settle r
		CROSS APPLY ( SELECT TOP 1 MatchID, eventdate, SportName, leaguename,LeagueGroupName, HomeName, AwayName
					 FROM #tmp_Matchid m
					 WHERE m.MatchID = r.MatchID
					 ) m
		LEFT JOIN #tmp_ResultProvider pr
			ON r.MatchID = pr.MatchID 
				AND r.ResourceID = pr.ResourceID
	) AS j
	PIVOT
	(
	  MAX(j.Score) FOR ProviderName IN (' + @columns+')
	) AS p';


	----Send email
	EXEC sp_executesql @sql;
	
	----Send Letstalk
	SELECT r.Sporttype
		  , pr.ProviderName
		  ,ROUND((COUNT(pr.ResourceID)/@TotalResult)*100 ,2) AS Accuracy
	FROM #tmp_Settle r
		INNER JOIN #tmp_ResultProvider pr
			ON r.MatchID = pr.MatchID 
				AND r.ResourceID = pr.ResourceID
				AND ISNULL(pr.homevalue,'') =  ISNULL(r.homevalue,'') 
				AND ISNULL(pr.awayvalue,'') =  ISNULL(r.awayvalue,'')
	GROUP BY pr.ProviderName, r.Sporttype

	DROP TABLE #tmp_Matchid
	DROP TABLE #tmp_Settle
	DROP TABLE #tmp_ResultProvider
	DROP TABLE #tmp_ProviderInfo
END
GO