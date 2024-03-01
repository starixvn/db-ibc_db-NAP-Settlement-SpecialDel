/*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="0"></info>*/
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
    DB: DBACC-bodb02

    Revisions:
        -20231120@Louisa: Init [Redmine:#197548]
		-20231219@Louisa: Exclude RedCat88 [Redmine:#198365]
		-20240222@Louisa: Move SP from DBPRO to DBACC [Redmine:#201196]
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
			,@IsActive		 BIT = 0
			,@Is14			 BIT = 0
			,@IsBK			 BIT = 0

    DROP TABLE IF EXISTS  #tmp_matchInfo

    CREATE TABLE #tmp_matchInfo ( MatchId INT, eventdate DATETIME, leaguename  NVARCHAR(1000), GameSession TINYINT, HomeName NVARCHAR(200), AwayName  NVARCHAR(200) )
    CREATE CLUSTERED INDEX IDX_tmp_matchInfo ON #tmp_matchInfo (MatchID)

	SELECT @maxEventDate14 = MAX(EventDate) FROM dbo.match14 m WITH(NOLOCK)
	SELECT @maxEventDateBK = MAX(EventDate) FROM bodb_archive.dbo.match_bk m WITH(NOLOCK)

	IF @toDate > @maxEventDate14
	SET @IsActive = 1

	IF @fromDate <= @maxEventDate14 AND @toDate > @maxEventDateBK
	SET @Is14 = 1

	IF @fromDate < @maxEventDateBK
	SET @IsBK = 1

	IF @IsActive = 1
	BEGIN
		INSERT INTO #tmp_matchInfo ( MatchId, eventdate, leaguename, GameSession, HomeName, AwayName )
		SELECT m.matchid, m.eventdate, l.leaguename, l.GameSession, home.teamname AS HomeName, away.teamname AS AwayName 
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.league l with(nolock) on m.leagueid = l.leagueid
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
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
	IF @Is14 = 1
	BEGIN
		INSERT INTO #tmp_matchInfo ( MatchId, eventdate, leaguename, GameSession, HomeName, AwayName )
		SELECT m.matchid, m.eventdate, l.leaguename, l.GameSession, home.teamname AS HomeName, away.teamname AS AwayName 
		FROM dbo.match14 m WITH(NOLOCK)
			INNER JOIN dbo.league l with(nolock) on m.leagueid = l.leagueid
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE  m.sporttype = @SportType
			AND ISNULL(m.childmatchType,0) <> 200
			AND m.eventdate BETWEEN @FromDate AND  @ToDate
			AND l.isTest = 0
			AND 1 = CASE WHEN l.sporttype = 43 AND l.LeagueGroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						 ELSE 1 
					 END
	END

	IF @IsBK = 1
	BEGIN
		INSERT INTO #tmp_matchInfo ( MatchId, eventdate, leaguename, GameSession, HomeName, AwayName )
		SELECT m.matchid, m.eventdate, l.leaguename, l.GameSession, home.teamname AS HomeName, away.teamname AS AwayName 
		FROM bodb_archive.dbo.match_bk m WITH(NOLOCK)
			INNER JOIN dbo.league l with(nolock) on m.leagueid = l.leagueid
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
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
			@IsActive	= @IsActive
			,@Is14		= @Is14
			,@IsBK		= @IsBK
			,@SportType	= @SportType
	END

	IF  @SportType = 43
	BEGIN
		EXEC NAP_Settlement_Result_Statistics_Esports
			@IsActive	= @IsActive
			,@Is14		= @Is14
			,@IsBK		= @IsBK
			,@SportType	=  @SportType
	END

END