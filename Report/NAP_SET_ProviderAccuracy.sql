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

	CREATE TABLE #tmp_Matchid (MatchID INT, SportType SMALLINT)
	CREATE TABLE #tmp_Settle (MatchID INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), SportType SMALLINT)
	CREATE TABLE #tmp_ResultProvider ( SourceID INT, MatchId INT, ResourceID VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ProviderName VARCHAR(50) )	
	--CREATE INDEX IDX_tmp_ResultProvider ON #tmp_ResultProvider(MatchID, ResourceID)
	CREATE TABLE #tmp_ProviderInfo (SourceID INT, SourceName VARCHAR(50) )
 
	INSERT INTO #tmp_Matchid (MatchID, sporttype)
	SELECT m.matchid , m.SportType
	FROM match m WITH(NOLOCK)
		INNER JOIN league l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE m.sporttype = 2
	AND m.eventdate = @date
	AND m.eventstatus = 'completed'
	AND l.isTest = 0
	AND l.LeagueGroupID NOT IN ( 122)

	INSERT INTO #tmp_Settle (sporttype,MatchID, ResourceID, HomeValue, AwayValue )
	SELECT m.sporttype, r.MatchID, r.ResourceID, r.HomeValue, r.AwayValue
	FROM ResultDetail r WITH(NOLOCK)
		INNER JOIN #tmp_Matchid m ON r.MatchId = m.MatchID
	WHERE r.ResultStatusID IN (2, 5)
		AND 1 = CASE WHEN ResourceId = 'OT' AND ISNULL(HomeValue,'') = '' THEN 0 --Auto payout always settle null for this result
			ELSE 1
			END

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
  
	INSERT INTO #tmp_ResultProvider ( MatchId, SourceId, ResourceID, HomeValue, AwayValue)
	SELECT  r.MatchId, SourceId, ResourceID, HomeValue, AwayValue
	FROM cte_ResultProvider r
	WHERE rk = 1

	INSERT INTO #tmp_ProviderInfo ( SourceID, SourceName)
	SELECT SourceID, SourceName
	FROM DBPRO.bodb02.dbo.ProviderInfo p WITH(NOLOCK)
	WHERE SourceID < 1001

	SELECT @TotalResult =  (SELECT COUNT(1) FROM #tmp_Settle)

	SELECT r.Sporttype
		  , p.SourceName AS ProviderName
		  ,ROUND((COUNT(pr.ResourceID)/@TotalResult)*100 ,2) AS Accuracy
	FROM #tmp_Settle r
		INNER JOIN #tmp_ResultProvider pr
			ON r.MatchID = pr.MatchID 
				AND r.ResourceID = pr.ResourceID
				AND ISNULL(pr.homevalue,'') =  ISNULL(r.homevalue,'') 
				AND ISNULL(pr.awayvalue,'') =  ISNULL(r.awayvalue,'')
		INNER JOIN #tmp_ProviderInfo p ON pr.SourceID = p.SourceID
	GROUP BY p.SourceName, r.Sporttype

	DROP TABLE #tmp_Matchid
	DROP TABLE #tmp_Settle
	DROP TABLE #tmp_ResultProvider
	DROP TABLE #tmp_ProviderInfo
END
GO