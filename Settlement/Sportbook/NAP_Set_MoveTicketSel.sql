/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MoveTicketSel
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@TicketStatus	VARCHAR(MAX)	= '0'
	,@MatchStatus	VARCHAR(MAX)	= '0'
	,@Remark		TINYINT			= 0
	,@MatchCode		NVARCHAR(50)	= ''
	,@SportType		INT				
	,@LeagueId		INT				= 0
	,@IsIncludeTest BIT				= 0
AS
/*  
	Creator	: 20210205@Louisa
	Task	: Cricket AIO [Redmine:#148870]						
	DB		: DBTXN/bodb02

	Revisions:
		20210205@Louisa: initial SP

	Param's Explanation:
		@LeagueId = 0 : All leagues

		@TicketStatus:	Un-check all: 0
						Check all: '1,2,3,4'
						Some option is selected: example:
						(	1 - Marked
							2 - Un-Calculated Early Settle
							3 - Un-Calculated Single
							4 - Un-Calculated Parlay )

		@MatchStatus:	Un-check all: 0
						Check all: '1,2,3,4,5,6,7,8'
						Some option is selected: example: '1,3,5'
						(	1 - Closed
							2 - Running
							3 - Kicked-off/In-play
							4 - Over
							5 - Postponed
							6 - Completed
							7 - Refund
							8 - Internal )

		@Remark:	Un-check all: 0
					Check all: 87
					- MTD Hold: 16
					- Undecided: 2
					- Result Pending: 1
					- Under Settlement: 4
					- Hold Key : 64
					
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId			INT 
			,@minBettype		SMALLINT
			,@maxBettype		SMALLINT
			,@remoteQuery		NVARCHAR(MAX)
			,@strMatchIds		VARCHAR(MAX)
			,@strEarlyBettypes	VARCHAR(MAX)
			,@strResourceIds	VARCHAR(MAX)
			,@matchidList		VARCHAR(MAX) = ''

	DECLARE @tmpTicketStatus TABLE(Id TINYINT)
	DECLARE @tmpMatchStatus TABLE(Id TINYINT, EventStatus NVARCHAR(50))
	DECLARE @tmpQueueStatus TABLE(MatchId INT, IsCalculatingSingle TINYINT DEFAULT(0), IsCalculatingMP TINYINT DEFAULT(0))
	DECLARE @tmpMatchIds	TABLE ( MatchId INT, ParentId INT)

	DECLARE @tmpEarlyBettypeStatus TABLE(
		MatchId				INT
		,bettype			SMALLINT
		,isExistSingle		BIT DEFAULT(0)
		,isExistParlay		BIT DEFAULT(0)
		,isRunningSingle	BIT DEFAULT(0)
		,isWaitingSingle	BIT DEFAULT(0)
		,isRunningParlay	BIT DEFAULT(0)
		,isWaitingParlay	BIT DEFAULT(0)
	)

	BEGIN TRY
	SET @matchid = CASE 
					WHEN ISNUMERIC(@matchcode) = 1 THEN CAST(@matchcode AS INT)
					ELSE NULL
					END
	END TRY

	BEGIN CATCH
		SET @matchid = NULL
	END CATCH

	CREATE TABLE #tmpMatchIds (
		matchid							INT
		,matchcode						NVARCHAR(50)
		,leagueid						INT
		,sporttype						SMALLINT
		,kickofftime					DATETIME
		,homeid							INT
		,awayid							INT 
		,halftimehomescore 				INT
		,halftimeawayscore 				INT
		,finalhomescore					INT
		,finalawayscore					INT
		,eventstatus					NVARCHAR(50)
		,betstatus						NVARCHAR(50) 
		,suspenderhalftime				NVARCHAR(50)
		,suspenderfulltime				NVARCHAR(50)
		,settlementstatus				TINYINT
		,childmatchtype					TINYINT
		,IsCalculated					BIT
		,IsMultiCaled					BIT
		,IsRefund						BIT
		,IsCalRefund					BIT
		,IsHalfTimeCal					BIT
		,IsExistEarlyBettypesSingle		BIT DEFAULT (0)
		,IsExistEarlyBettypesParlay		BIT DEFAULT (0)
		,IsRunningEarlyBettypesSingle	BIT DEFAULT (0)
		,IsRunningEarlyBettypesParlay	BIT DEFAULT (0)
		,IsWaitingEarlyBettypesSingle	BIT DEFAULT (0)
		,IsWaitingEarlyBettypesParlay	BIT DEFAULT (0)
		,IsExistRunningBettypeSingle	BIT DEFAULT (0)		-- exclude early bettype
		,IsExistRunningTicketAfterCompleted	BIT DEFAULT (0) -- after match completed
	)
	 
	INSERT INTO @tmpTicketStatus(Id)
	SELECT	val
	FROM	dbo.f_SplitString(@TicketStatus, ',')
	OPTION (MAXRECURSION 0)

	INSERT INTO @tmpMatchStatus(Id, EventStatus)
	SELECT	val
			,CASE
				WHEN val = 1 THEN 'Closed'
				WHEN val IN (2,3,4) THEN 'running'
				WHEN val = 5 THEN 'Postponed'
				WHEN val = 6 THEN 'Completed'
				WHEN val = 8 THEN 'internal'
				ELSE ''
			END	
	FROM	dbo.f_SplitString(@MatchStatus, ',')
	OPTION (MAXRECURSION 0)

	
	INSERT INTO #tmpMatchIds(matchid
		,matchcode
		,leagueid
		,sporttype
		,kickofftime
		,homeid
		,awayid 
		,halftimehomescore
		,halftimeawayscore
		,finalhomescore
		,finalawayscore
		,eventstatus
		,betstatus 
		,suspenderhalftime
		,suspenderfulltime
		,settlementstatus
		,childmatchtype
		,IsCalculated
		,IsMultiCaled
		,IsRefund
		,IsCalRefund
		,IsHalfTimeCal 
	)
	SELECT	m.matchid
			,m.matchcode
			,l.LeagueId
			,m.sporttype
			,m.kickofftime
			,m.homeid
			,m.awayid 
			,m.hthomescore
			,m.htawayscore
			,m.finalhomescore
			,m.finalawayscore				
			,m.eventstatus
			,m.betstatus 
			,NULL
			,CASE mr.ConfirmFT
				WHEN 0 THEN ''
				ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmFT)
			END
			,m.SettlementStatus
			,m.ChildMatchType
			,mr.calculate
			,mr.multiple
			,mr.refund
			,mr.calrefund
			,mr.IsHTCal
	FROM	dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.League l WITH(NOLOCK)
			ON	m.leagueid = l.LeagueId
		LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
			ON	m.matchid = mr.matchid	
	WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
			AND (@matchcode = '' OR (m.matchid = @matchid OR m.matchcode LIKE + '%' + @matchcode + '%')) 
			AND m.sporttype = @Sporttype
			AND ISNULL(m.ChildMatchType,0) <> 200
			AND m.leagueID = CASE WHEN @LeagueID <> 0 THEN @LeagueID ELSE m.leagueID END
			AND (@Remark = 0 OR @Remark & m.SettlementStatus > 0)
			AND l.isTest = CASE WHEN @IsIncludeTest = 0 THEN 0 ELSE l.isTest END
			AND EXISTS (
				SELECT TOP 1 1
				FROM	@tmpMatchStatus s
				WHERE	m.eventstatus = CASE 
											WHEN s.Id IN (0, 7) THEN m.eventstatus
											ELSE s.EventStatus
										END
						AND 1 = CASE
									WHEN s.Id NOT IN (3,4,6,7) THEN 1
									WHEN s.Id = 3 AND m.kickofftime < GETDATE() THEN 1 -- kicked-off/in-play: 'Running' and have passed Kick-off Time.
									WHEN s.Id = 4 AND mr.ConfirmFT > 0 THEN 1 -- Over: 'Running' and have full time scores confirmed.
									WHEN s.Id = 6 AND m.betstatus NOT LIKE '%Refund%' THEN 1	
									WHEN s.Id = 7 AND m.betstatus LIKE '%Refund%' THEN 1									
									ELSE 0
								END
			) 
	CREATE TABLE #ChildMatch ( MatchId INT, ParentId INT )

	SELECT @matchidList =	@matchidList + ',' + CAST(matchid AS VARCHAR(20)) FROM #tmpMatchIds
	SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))
	
	INSERT INTO #ChildMatch ( MatchId, ParentId  ) EXEC DBPRO.bodb02.dbo.NAP_Set_GetChildMatch @MatchIds = @matchidList
	SET @matchidList = ''

	;WITH singlequeue 
	AS(
		SELECT	s.matchid
				,MIN(s.IsCalculating) AS IsCalculatingSingle
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	s.Starttime > DATEADD(MINUTE, -10, GETDATE())
				AND s.IsCalculating IN (0,1)
				AND s.SportType = @SportType
		GROUP BY s.matchid
	)
	,parlayqueue
	AS(
		SELECT	p.matchid
				,MIN(p.IsCalculating) AS IsCalculatingMP
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE	p.Starttime > DATEADD(MINUTE, -10, GETDATE())
				AND p.IsCalculating IN (0,1)
		GROUP BY p.matchid
	)
	INSERT INTO @tmpQueueStatus(MatchId, IsCalculatingSingle, IsCalculatingMP)
	SELECT	ISNULL(s.matchid, p.matchid) AS matchid
			,s.IsCalculatingSingle
			,p.IsCalculatingMP
	FROM	singlequeue s
		FULL OUTER JOIN parlayqueue p
			ON	s.matchid = p.matchid

	SELECT	@minBettype = MIN(bettype)
			,@maxBettype = MAX(bettype)
	FROM	dbo.f_Set_GetEarlyBettypes()

	INSERT INTO @tmpEarlyBettypeStatus(MatchId, isExistSingle, isRunningSingle, isWaitingSingle, isExistParlay, isRunningParlay, isWaitingParlay)
	SELECT	DISTINCT m.ParentId
			,MAX(b.isExistSingle)
			,MAX(b.IsRunningSingle)
			,MAX(b.IsWaitingSingle)
			,MAX(b.isExistParlay)
			,MAX(b.isRunningParlay)
			,MAX(b.isWaitingParlay)
	FROM	#ChildMatch  m
		CROSS APPLY (
			SELECT	b.bettype
					,MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) AS IsRunningSingle
					,MAX(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) AS IsWaitingSingle
					,1 AS isExistSingle
					,0 AS isRunningParlay
					,0 AS isWaitingParlay					
					,0 AS isExistParlay
			FROM	dbo.bettrans b WITH(NOLOCK)
			WHERE	b.matchid = m.matchid
					AND b.statusID NOT IN(101, 102)
					AND b.bettype BETWEEN @minBettype AND @maxBettype
			GROUP BY b.bettype, b.matchid
			UNION ALL
			SELECT	bm.bettype
					,0 AS IsRunningSingle
					,0 AS IsWaitingSingle
					,0 AS isExistSingle
					,MAX(CASE WHEN bm.statusID = 0 THEN 1 ELSE 0 END) AS IsRunningParlay
					,MAX(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) AS IsWaitingParlay					
					,1 AS isExistParlay
			FROM	dbo.bettransm bm WITH(NOLOCK)
			WHERE	bm.matchid = m.matchid
					AND bm.statusID NOT IN (101, 102)
					AND bm.bettype BETWEEN @minBettype AND @maxBettype
			GROUP BY bm.bettype, bm.MatchId
		)b
		INNER JOIN dbo.f_Set_GetEarlyBettypes() f
			ON b.bettype = f.bettype
	GROUP BY m.ParentId

	UPDATE m
		SET  IsExistEarlyBettypesSingle = b.isExistSingle
			,IsExistEarlyBettypesParlay = b.isExistParlay
			,IsRunningEarlyBettypesSingle = b.isRunningSingle
			,IsRunningEarlyBettypesParlay = b.isRunningParlay
			,IsWaitingEarlyBettypesSingle = b.isWaitingSingle
			,IsWaitingEarlyBettypesParlay = b.isWaitingParlay
	FROM	#tmpMatchIds m 
		INNER JOIN @tmpEarlyBettypeStatus b
			ON m.matchid = b.MatchId
	UPDATE m
		SET IsExistRunningBettypeSingle = 1
	FROM	#tmpMatchIds m
		INNER JOIN (
			SELECT	m.ParentId
					,MAX(b.IsRunningBettypeSingle) AS IsRunningBettypeSingle
			FROM #ChildMatch m
			CROSS APPLY (
				SELECT	b.bettype
						,MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) AS IsRunningBettypeSingle
				FROM	dbo.bettrans b WITH(NOLOCK)
				WHERE	m.matchid = b.matchid
				GROUP BY b.bettype
			) b
			INNER JOIN dbo.f_Set_GetGroupBettypes() f
				ON	b.bettype = f.BetType
			LEFT JOIN dbo.f_Set_GetEarlyBettypes() e
				ON	b.bettype = e.bettype
			WHERE	e.bettype IS NULL
			GROUP BY m.ParentId
		)t
			ON m.matchid = t.ParentId
	WHERE t.IsRunningBettypeSingle = 1

	IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpTicketStatus WHERE id = 0)
	BEGIN
		DELETE	m
		FROM	#tmpMatchIds m
		WHERE	NOT EXISTS (
			SELECT TOP 1 1
			FROM	@tmpTicketStatus t
			WHERE	1 = CASE
							WHEN t.Id = 0 THEN 1
							WHEN t.Id = 2 AND m.IsExistEarlyBettypesSingle > 0 AND m.IsRunningEarlyBettypesSingle > 0 THEN 1 -- un-calculated early
							WHEN t.Id = 3 AND m.IsExistRunningBettypeSingle = 1 THEN 1 -- un-calculate single
							WHEN t.Id = 4 AND (ISNULL(m.IsCalculated,0) = 1 OR ISNULL(m.IsCalRefund,0) = 1) AND (ISNULL(m.IsMultiCaled,0) = 0 AND ISNULL(m.IsRefund,0) = 0) THEN 1 -- un-calculate parlay
							ELSE 0
						END
		)
	END
	
	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0))

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	matchid
	FROM	#tmpMatchIds
	WHERE	eventstatus = 'completed'

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE m 
			SET IsExistRunningTicket = 1
		FROM	@tmpMatchCompleted m
			CROSS APPLY (
				SELECT	b.matchid
				FROM	dbo.bettrans b WITH(NOLOCK)	
				WHERE	b.matchid = m.matchid
						AND b.statusID = 0
				GROUP BY b.matchid
			)b

		UPDATE m 
			SET IsExistRunningTicketAfterCompleted = t.IsExistRunningTicket
		FROM	#tmpMatchIds m
			INNER JOIN @tmpMatchCompleted t
				ON	m.matchid = t.MatchId
	END

	SELECT	m.matchid
			,m.matchcode
			,m.leagueid
			,m.sporttype
			,m.kickofftime
			,m.homeid
			,m.awayid 
			,m.halftimehomescore
			,m.halftimeawayscore
			,m.finalhomescore
			,m.finalawayscore
			,m.eventstatus
			,m.betstatus 
			,suspenderhalftime
			,m.suspenderfulltime
			,m.settlementstatus
			,q.IsCalculatingSingle
			,q.IsCalculatingMP
			,m.IsCalculated
			,m.IsMultiCaled
			,m.IsRefund
			,m.IsCalRefund
			,m.IsHalfTimeCal
			,CASE
				WHEN m.IsExistEarlyBettypesSingle = 0 AND m.IsExistEarlyBettypesParlay = 0 THEN 'N/A'
				WHEN m.IsRunningEarlyBettypesSingle = 1 THEN 'Running'
				WHEN m.IsWaitingEarlyBettypesSingle = 1 THEN 'Waiting'
				WHEN m.IsExistEarlyBettypesSingle = 0 AND m.IsRunningEarlyBettypesParlay = 1 THEN 'Parlay Running'
				WHEN m.IsExistEarlyBettypesSingle = 0 AND m.IsWaitingEarlyBettypesParlay = 1 THEN 'Parlay Waiting'
				ELSE 'Completed'
			END AS EarlySettleStatus
			,m.IsExistRunningTicketAfterCompleted AS IsExistRunningTicket
	FROM	#tmpMatchIds m
		LEFT JOIN @tmpQueueStatus q
			ON	m.matchid = q.MatchId
	
	SELECT @matchidList =  @matchidList + ',' + CAST(matchid AS VARCHAR(20))
	FROM #tmpMatchIds

	SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))
	 
	EXEC DBPRO.bodb02.dbo.NAP_Set_ResultDetailSel
		@matchidList = @matchidList

END

GO