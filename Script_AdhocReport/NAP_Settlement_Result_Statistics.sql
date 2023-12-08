/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Settlement_Result_Statistics
(
	@FromDate	DATETIME 
	,@ToDate	DATETIME 
	,@SportType	SMALLINT 
)
AS
/*
    Created: 20231120@Louisa
    Task : Internal report for Cricket-result settle and Provider score [Redmine:#197548]
    DB: DBPRO/bodb02

    Revisions:
		-20231120@louisa: Init [Redmine:#197548]
*/
BEGIN
	SET NOCOUNT ON;
	/*
	--DECLARE @FromDate	DATETIME = '2023-11-24 00:00:00.000'
	--		,@ToDate	DATETIME = '2023-11-30 00:00:00.000'
	--		,@SportType	SMALLINT = 50 
	exec NAP_Settlement_Result_Statistics
		@FromDate	=  '2023-11-24 00:00:00.000'
		,@ToDate	=  '2023-11-30 00:00:00.000'
		,@SportType	=  43

	*/

	DROP TABLE IF EXISTS  #tmp_matchInfo
	DROP TABLE IF EXISTS  #tmp_ResultSettle

	CREATE TABLE #tmp_matchInfo ( MatchId INT, eventdate DATETIME, leaguename  NVARCHAR(1000), GameSession TINYINT, HomeName NVARCHAR(200), AwayName  NVARCHAR(200), Is14 BIT)
	CREATE TABLE #tmp_ResultSettle ( MatchId INT, SourceID INT, ResourceID VARCHAR(50), HomeValue VARCHAR(50), AwayValue VARCHAR(50), eventdate DATETIME, leaguename  NVARCHAR(1000), GameSession TINYINT, HomeName NVARCHAR(200), AwayName  NVARCHAR(200))
	
	CREATE INDEX IDX_tmp_ResultSettle ON #tmp_ResultSettle(MatchID, ResourceID)
	CREATE INDEX IDX_tmp_matchInfo ON #tmp_matchInfo(MatchID)

	DECLARE @ResultTable TINYINT  = ( SELECT s.ResultTable FROM SettlementResultTableSetting s WITH(NOLOCK) WHERE s.Sporttype = @SportType )

	INSERT INTO #tmp_matchInfo ( MatchId, eventdate, leaguename, GameSession, HomeName, AwayName, Is14)
	SELECT m.matchid, m.eventdate, l.leaguename, l.GameSession, home.teamname AS HomeName, away.teamname AS AwayName, m.Is14
	FROM  
		(	SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.leagueid, 0 AS Is14
			FROM match m WITH(NOLOCK)
			WHERE  m.sporttype = @SportType
				AND ISNULL(m.childmatchType,0) <> 200
				AND m.eventdate > @FromDate 
				AND m.eventdate <= @ToDate				
				AND m.eventstatus <> 'closed'
				AND m.IsDeleted = 0
			UNION ALL
			SELECT m.matchid, m.eventdate, m.homeid, m.awayid, m.leagueid, 1 AS Is14
			FROM match14 m WITH(NOLOCK)
			WHERE  m.sporttype = @SportType
				AND ISNULL(m.childmatchType,0) <> 200
				AND m.eventdate > @FromDate 
				AND m.eventdate <= @ToDate				
				AND m.eventstatus <> 'closed'

		) m
		INNER JOIN league l with(nolock) on m.leagueid = l.leagueid
		INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
		INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
	WHERE l.isTest = 0
		AND 1 = CASE WHEN l.sporttype = 43 AND l.LeagueGroupID = 151 THEN 0
					 ELSE 1 
                 END
	
	IF @ResultTable = 2
	BEGIN
		INSERT INTO #tmp_ResultSettle ( MatchId, SourceID, ResourceID, HomeValue, AwayValue, eventdate, leaguename, GameSession , HomeName, AwayName)
		SELECT r.MatchId, 0 AS SourceID, r.ResourceID, r.HomeValue, r.AwayValue , m.eventdate, m.leaguename, m.GameSession , HomeName, AwayName
		FROM ResultDetailOS r WITH(NOLOCK)
			INNER JOIN	#tmp_matchInfo m
				ON r.matchid = m.matchid 
		WHERE r.ResultStatusID IN (2, 5)
			AND m.Is14 = 0

		INSERT INTO #tmp_ResultSettle ( MatchId, SourceID, ResourceID, HomeValue, AwayValue, eventdate, leaguename, GameSession , HomeName, AwayName)
		SELECT r.MatchId, 0 AS SourceID, r.ResourceID, r.HomeValue, r.AwayValue , m.eventdate, m.leaguename, m.GameSession , HomeName, AwayName
		FROM ResultDetailOS14 r WITH(NOLOCK)
			INNER JOIN	#tmp_matchInfo m
				ON r.matchid = m.matchid 
		WHERE r.ResultStatusID IN (2, 5)
			AND m.Is14 = 1

		IF @SportType = 50
		BEGIN
			EXEC NAP_Settlement_Result_Statistics_Cricket
				@FromDate	=  @FromDate
				,@ToDate	=  @ToDate
				,@SportType	=  @SportType
		END
	END

	IF @ResultTable = 3 --ESports
	BEGIN
		INSERT INTO #tmp_ResultSettle ( MatchId, SourceID, ResourceID, HomeValue, AwayValue, eventdate, leaguename, HomeName, AwayName)
		SELECT r.MatchId, 0 AS SourceID, r.ResourceID, r.HomeValue, r.AwayValue , m.eventdate, m.leaguename, HomeName, AwayName
		FROM ResultDetailES r WITH(NOLOCK)
			INNER JOIN	#tmp_matchInfo m
				ON r.matchid = m.matchid 
		WHERE r.ResultStatusID IN (2, 5)
			AND m.Is14 = 0

		INSERT INTO #tmp_ResultSettle ( MatchId, SourceID, ResourceID, HomeValue, AwayValue, eventdate, leaguename , HomeName, AwayName)
		SELECT r.MatchId, 0 AS SourceID, r.ResourceID, r.HomeValue, r.AwayValue , m.eventdate, m.leaguename, HomeName, AwayName
		FROM ResultDetailES14 r WITH(NOLOCK)
			INNER JOIN	#tmp_matchInfo m
				ON r.matchid = m.matchid 
		WHERE r.ResultStatusID IN (2, 5)
			AND m.Is14 = 1

		EXEC NAP_Settlement_Result_Statistics_Esports
			@FromDate	=  @FromDate
			,@ToDate	=  @ToDate
			,@SportType	=  @SportType
	END


END
GO
 