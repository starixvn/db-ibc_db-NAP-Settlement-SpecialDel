/*<info serverAlias="DBARC-bodb_archive" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE NAP_Settlement_Result_Statistics
(
    @FromDate   DATETIME 
    ,@ToDate    DATETIME 
    ,@SportType SMALLINT 
)
AS
/*
    Created: 20231120@Louisa
    Task : Internal report for Cricket-result settle and Provider score [Redmine:#197548]
    DB: DBARC/bodb_archive

    Revisions:
        -20231120@Louisa: Init [Redmine:#197548]
		-20231219@Louisa: Exclude RedCat88 [Redmine:#198365]
		-20240222@Louisa: Move SP from DBPRO to DBARC [Redmine:#201196]
*/
BEGIN
    SET NOCOUNT ON;
    /*
    --DECLARE @FromDate DATETIME = '2023-11-24 00:00:00.000'
    --      ,@ToDate    DATETIME = '2023-11-30 00:00:00.000'
    --      ,@SportType SMALLINT = 50 
    exec NAP_Settlement_Result_Statistics
        @FromDate   =  '2023-11-24 00:00:00.000'
        ,@ToDate    =  '2023-11-30 00:00:00.000'
        ,@SportType =  50

	exec NAP_Settlement_Result_Statistics
		@FromDate	=  '2023-11-24 00:00:00.000'
		,@ToDate	=  '2023-11-30 00:00:00.000'
		,@SportType	=  43

    */

	DECLARE  @maxEventDate14 DATETIME
			,@maxEventDateBK DATETIME
	
    DROP TABLE IF EXISTS  #tmp_matchInfo

    CREATE TABLE #tmp_matchInfo ( MatchId INT, eventdate DATETIME, leaguename  NVARCHAR(1000), GameSession TINYINT, HomeName NVARCHAR(200), AwayName  NVARCHAR(200) )
    CREATE CLUSTERED INDEX IDX_tmp_matchInfo ON #tmp_matchInfo (MatchID)

	SELECT @maxEventDate14 = MAX(EventDate) FROM bodb02.dbo.match14 m WITH(NOLOCK)
	SELECT @maxEventDateBK = MAX(EventDate) FROM dbo.match_bk m WITH(NOLOCK)

	IF @toDate > @maxEventDate14
	BEGIN
		INSERT INTO #tmp_matchInfo ( MatchId, eventdate, leaguename, GameSession, HomeName, AwayName )
		SELECT m.matchid, m.eventdate, l.leaguename, l.GameSession, home.teamname AS HomeName, away.teamname AS AwayName 
		FROM bodb02.dbo.match m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
			INNER JOIN bodb02.dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN bodb02.dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE  m.sporttype = @SportType
			AND ISNULL(m.childmatchType,0) <> 200
			AND m.eventdate BETWEEN @FromDate AND  @ToDate
			AND m.IsDeleted = 0
			AND l.isTest = 0
			AND 1 = CASE WHEN l.sporttype = 43 AND l.LeagueGroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						 ELSE 1 
					 END
	END

	--match14
	IF @fromDate <= @maxEventDate14 AND @toDate > @maxEventDateBK
	BEGIN
		INSERT INTO #tmp_matchInfo ( MatchId, eventdate, leaguename, GameSession, HomeName, AwayName )
		SELECT m.matchid, m.eventdate, l.leaguename, l.GameSession, home.teamname AS HomeName, away.teamname AS AwayName 
		FROM bodb02.dbo.match14 m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
			INNER JOIN bodb02.dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN bodb02.dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE  m.sporttype = @SportType
			AND ISNULL(m.childmatchType,0) <> 200
			AND m.eventdate BETWEEN @FromDate AND  @ToDate
			AND l.isTest = 0
			AND 1 = CASE WHEN l.sporttype = 43 AND l.LeagueGroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						 ELSE 1 
					 END
	END

	IF @fromDate < @maxEventDateBK
	BEGIN
		INSERT INTO #tmp_matchInfo ( MatchId, eventdate, leaguename, GameSession, HomeName, AwayName )
		SELECT m.matchid, m.eventdate, l.leaguename, l.GameSession, home.teamname AS HomeName, away.teamname AS AwayName 
		FROM dbo.match_bk m WITH(NOLOCK)
			INNER JOIN bodb02.dbo.league l with(nolock) on m.leagueid = l.leagueid
			INNER JOIN bodb02.dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN bodb02.dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE  m.sporttype = @SportType
			AND ISNULL(m.childmatchType,0) <> 200
			AND m.eventdate BETWEEN @FromDate AND  @ToDate
			AND l.isTest = 0
			AND 1 = CASE WHEN l.sporttype = 43 AND l.LeagueGroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						 ELSE 1 
					 END

	END

	IF @SportType = 50
	BEGIN
		EXEC NAP_Settlement_Result_Statistics_Cricket
			@FromDate	=  @FromDate
			,@ToDate	=  @ToDate
			,@SportType	=  @SportType
	END

	IF  @SportType = 43
	BEGIN
		EXEC NAP_Settlement_Result_Statistics_Esports
			@FromDate	=  @FromDate
			,@ToDate	=  @ToDate
			,@SportType	=  @SportType
	END

END