/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Set_MatchNoTicketSel
(
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@MatchStatus	VARCHAR(MAX)	= '0'
	,@HoldStatus	VARCHAR(10)		= '0'
	,@MatchCode		NVARCHAR(50)	= ''
	,@Sporttypes	VARCHAR(MAX)	
	,@LeagueIds		VARCHAR(MAX)
	,@IsIncludeTest BIT				= 0
)
AS
/*
		Created By : 20211125@Louisa
		Task: Delete Match no ticket
		DB: DBTXN-bodb02

		Revisions:
				- 20211125@Louisa: query main page [Redmine:#163469]

		Param explanation:

			@MatchStatus:	Un-check all: '0'
							Check all: '1,2,3,4,5,6'
							Some option is selected: example: '1,3,5'
							(	1 - Closed
								2 - Running
								3 - Kicked-off/In-play
								4 - Postponed	
								5 - Completed
								6 - Refund
								7 - Internal )

			@HoldStatus:  '0'	- Uncheck
						  '1'	- Not Hold  
						  '2'	- Hold ( SettlementStatus bit 1 or 2 or 3 or 5 or 7 turned on )
						  '1,2' - Check All
						  						
			@sporttype: multiple selected
			@leagueid: multiple selected

*/
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#tmpMatchIds') IS NOT NULL DROP TABLE #tmpMatchIds
	IF OBJECT_ID('tempdb..#CheckOdds') IS NOT NULL DROP TABLE #CheckOdds

	DECLARE @MatchId		INT
			,@RemoteQuery	VARCHAR(MAX) = ''
			,@strMatchId	VARCHAR(MAX) = ''
			,@strMatchIdOS	VARCHAR(MAX) = ''
			,@strMatchIdES	VARCHAR(MAX) = ''
	DECLARE @tmpLeagueIds   TABLE (LeagueId INT)
	DECLARE @tmpSporttypes  TABLE (Sporttype SMALLINT)
	DECLARE @tmpMatchStatus TABLE (Id TINYINT, EventStatus NVARCHAR(50))
	DECLARE @tmpHoldStatus  TABLE (HoldStatus TINYINT)

	CREATE TABLE #tmpMatchIds (
			matchid				INT
			,matchcode			NVARCHAR(50)
			,leagueid			INT
			,sporttype			SMALLINT
			,kickofftime		DATETIME
			,homeid				INT
			,awayid				INT		
			,eventstatus		NVARCHAR(50)
			,betstatus			NVARCHAR(50)
			,settlementstatus	TINYINT
			,EventStatusReason	TINYINT
			,IsRunningOdds		BIT DEFAULT (0)
		)
	
	CREATE TABLE #CheckOdds ( MatchId INT )

	IF @MatchCode <> ''
	BEGIN
		SELECT	@MatchStatus	= '0'
				,@LeagueIds		= ''
				,@HoldStatus	= '0'
				,@IsIncludeTest = 1
	END

	IF ISNUMERIC(@MatchCode) = 1
	BEGIN
		SET @MatchId = CAST(@MatchCode AS INT)
	END

	INSERT INTO @tmpSporttypes(Sporttype)
	SELECT	DISTINCT val
	FROM	dbo.f_SplitString(@Sporttypes, ',')
	OPTION (MAXRECURSION 0)

	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT	DISTINCT val
	FROM	dbo.f_SplitString(@LeagueIds, ',')
	OPTION (MAXRECURSION 0)

	INSERT INTO @tmpMatchStatus(Id, EventStatus)
	SELECT	val
			,CASE
				WHEN val = 1 THEN 'Closed'
				WHEN val IN (2,3) THEN 'running'
				WHEN val = 4 THEN 'Postponed'
				WHEN val = 5 THEN 'Completed'
				WHEN val = 7 THEN 'internal'
				ELSE ''
			END	
	FROM	dbo.f_SplitString(@MatchStatus, ',')
	OPTION (MAXRECURSION 0)

	INSERT INTO @tmpHoldStatus ( HoldStatus ) 
	SELECT CAST(val AS TINYINT) FROM dbo.f_SplitString(@HoldStatus, ',')
	OPTION (MAXRECURSION 0)
	
	IF @MatchCode <> ''
	BEGIN
		INSERT INTO #tmpMatchIds
		(
			m.matchid
			,matchcode
			,leagueid
			,sporttype
			,kickofftime
			,homeid
			,awayid
			,eventstatus
			,betstatus	
			,settlementStatus
			,EventStatusReason
		)
		SELECT m.matchid
		 , m.matchcode
		 , m.leagueid
		 , m.sporttype
		 , m.kickofftime
		 , m.homeid
		 , m.awayid
		 , m.eventstatus
		 , m.betstatus	
		 , m.settlementStatus
		 , m.EventStatusReason
	FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK)
		INNER JOIN @tmpSporttypes s
				ON m.sporttype = s.Sporttype
	WHERE (m.matchid = @MatchId OR m.matchcode LIKE + '%' + @MatchCode + '%')
		AND m.eventdate BETWEEN @FromDate AND @ToDate
		AND ISNULL(m.IsDeleted,0) = 0
	END
	
	ELSE
	BEGIN
		INSERT INTO #tmpMatchIds
		(
			m.matchid
			,matchcode
			,leagueid
			,sporttype
			,kickofftime
			,homeid
			,awayid
			,eventstatus
			,betstatus	
			,settlementStatus
			,EventStatusReason
		)
		SELECT m.matchid
			 , m.matchcode
			 , m.leagueid
			 , m.sporttype
			 , m.kickofftime
			 , m.homeid
			 , m.awayid
			 , m.eventstatus
			 , m.betstatus	
			 , m.settlementStatus
			 , m.EventStatusReason
		FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK)
			INNER JOIN @tmpSporttypes s
				ON m.sporttype = s.Sporttype
			INNER JOIN @tmpLeagueIds tmp
				ON	m.leagueid = tmp.LeagueId
			CROSS APPLY (
					SELECT TOP 1 l.LeagueId
					FROM dbo.League l WITH(NOLOCK)
					WHERE l.leagueid = tmp.leagueid
						AND l.isTest = CASE WHEN @IsIncludeTest = 0 THEN 0 ELSE l.isTest END
						AND ISNULL(l.IsDeleted,0) = 0
				) l
		WHERE m.eventdate BETWEEN @FromDate AND @ToDate
			AND ISNULL(m.IsDeleted,0) = 0			
			AND EXISTS (
					SELECT TOP 1 1
					FROM	@tmpMatchStatus s
					WHERE	m.eventstatus = CASE 
												WHEN s.Id IN (0, 6) THEN m.eventstatus
												ELSE s.EventStatus
											END
							AND 1 = CASE
										WHEN s.Id NOT IN (3,5,6) THEN 1
										WHEN s.Id = 3 AND m.kickofftime < GETDATE() THEN 1
										WHEN s.Id = 5 AND m.betstatus NOT LIKE '%Refund%' THEN 1
										WHEN s.Id = 6 AND m.betstatus LIKE '%Refund%' THEN 1								
										ELSE 0
									END
					)
				AND EXISTS (
							SELECT TOP 1 h.HoldStatus
							FROM @tmpHoldStatus h
							WHERE 1 = CASE  WHEN h.HoldStatus = 0 THEN 1
											WHEN h.HoldStatus = 1 AND m.SettlementStatus & 87 > 1 THEN 1
											WHEN h.HoldStatus  = 2 AND m.SettlementStatus & 87 = 0 THEN 1
											ELSE 0
										END
						)
		END

	DELETE tmp
	FROM #tmpMatchIds tmp
		CROSS APPLY (	SELECT TOP 1 m.ParentID
						FROM DBPRO.bodb02.dbo.match m WITH(NOLOCK)
						WHERE	m.ParentID IS NOT NULL
							AND m.ParentID = tmp.matchid
							AND ISNULL(m.IsDeleted,0) = 0
					) m

	DELETE tmp
	FROM #tmpMatchIds tmp
		CROSS APPLY (
			SELECT TOP 1 b.matchid
			FROM dbo.Bettrans b WITH(NOLOCK)
			WHERE b.matchid = tmp.matchid

			UNION ALL
			SELECT TOP 1 bm.matchid
			FROM dbo.Bettransm bm WITH(NOLOCK)
			WHERE bm.matchid = tmp.matchid
		) b
		
	SELECT @strMatchIdES =  @strMatchIdES + ',' + CAST(matchid AS VARCHAR(20))	FROM #tmpMatchIds WHERE sporttype = 43
	SELECT @strMatchIdOS =  @strMatchIdOS + ',' + CAST(matchid AS VARCHAR(20))	FROM #tmpMatchIds WHERE sporttype  IN ( 9, 45, 50)
	SELECT @strMatchId	 =  @strMatchId + ',' + CAST(matchid AS VARCHAR(20))	FROM #tmpMatchIds WHERE sporttype NOT IN ( 9, 45, 43, 50 )
		
	SET @strMatchIdES = SUBSTRING(@strMatchIdES, 2, LEN(@strMatchIdES))
	SET @strMatchIdOS = SUBSTRING(@strMatchIdOS, 2, LEN(@strMatchIdOS))
	SET @strMatchId = SUBSTRING(@strMatchId, 2, LEN(@strMatchId))

	IF ISNULL(@strMatchIdES,'') <> ''
	BEGIN
		SET @remoteQuery = '
		SELECT *
		FROM OPENQUERY(DBPRO, ''SELECT	DISTINCT o.matchid 
							FROM	DBPRO.bodb02.dbo.oddsES o WITH(NOLOCK)
							WHERE o.MatchId IN ('+@strMatchIdES+')
								AND o.OddsStatus NOT IN (''''closed'''', ''''internal'''')
								AND ISNULL(o.IsDeleted,0) = 0
						'')' 
		INSERT INTO #CheckOdds (Matchid)
		EXECUTE (@remoteQuery)
	END

	IF ISNULL(@strMatchIdOS,'') <> ''
	BEGIN
		SET @remoteQuery = '
		SELECT *
		FROM OPENQUERY(DBPRO, ''SELECT	DISTINCT o.matchid 
							FROM	DBPRO.bodb02.dbo.oddsOS o WITH(NOLOCK)
							WHERE o.MatchId IN ('+@strMatchIdOS+')
								AND o.OddsStatus NOT IN (''''closed'''', ''''internal'''')
								AND ISNULL(o.IsDeleted,0) = 0
						'')' 
		INSERT INTO #CheckOdds (Matchid)
		EXECUTE (@remoteQuery)
	END

	IF ISNULL(@strMatchId,'') <> ''
	BEGIN
		SET @remoteQuery = '
		SELECT *
		FROM OPENQUERY(DBPRO, ''SELECT	DISTINCT o.matchid 
							FROM	DBPRO.bodb02.dbo.odds o WITH(NOLOCK)
							WHERE o.MatchId IN ('+@strMatchId+')
								AND o.OddsStatus NOT IN (''''closed'''', ''''internal'''')
								AND ISNULL(o.IsDeleted,0) = 0
						'')' 
		INSERT INTO #CheckOdds (Matchid)
		EXECUTE (@remoteQuery)
	END

	UPDATE m
	SET IsRunningOdds = 1
	FROM #tmpMatchIds m
		INNER JOIN #CheckOdds o
			ON m.matchid = o.MatchId

	SELECT matchid				
			,matchcode			
			,leagueid			
			,sporttype			
			,kickofftime		
			,homeid				
			,awayid				
			,eventstatus		
			,betstatus			
			,settlementstatus	
			,EventStatusReason	
			,IsRunningOdds		
	FROM #tmpMatchIds
		
END
GO


