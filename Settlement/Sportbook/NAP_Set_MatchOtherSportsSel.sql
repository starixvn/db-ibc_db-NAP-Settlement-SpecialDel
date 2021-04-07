/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_MatchOtherSportsSel
	@FromDate		DATETIME
	,@ToDate		DATETIME
	,@TicketStatus	VARCHAR(MAX)	= '0'
	,@MatchStatus	VARCHAR(MAX)	= '0'
	,@Remark		TINYINT			= 0
	,@MatchCode		NVARCHAR(50)	= ''
	,@Sporttypes	VARCHAR(MAX)	
	,@LeagueIds		VARCHAR(MAX) 
	,@IsIncludeTest BIT				= 0
	,@AutoSetting 			TINYINT = 0
AS
/*  
	 Created by: Kathy
	 Date: 20200528
	 Task: Match results for other sports [Redmine:#134843] 
	 DB: DBTXN/bodb02
	 
	 Revisions:  
			- 20200528@Kathy: Match results for other sports [Redmine:#134843] 
			- 20200827@Louisa: get external result to compare [Redmine:#139979]
			- 20201027@Louisa: Add new settlement status - Hold Key bit[7] - [Redmine:#143441]
			- 20210205@Louisa: Cricket AIO [Redmine:#148870]
			- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
			- 20210324@Louisa: Enhancement MultiSports page [Redmine:#151545]
      
	 Param explanation:  
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
							8 - Internal
							9 - Interval Over )

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
			,@n					INT 
			,@minBettype		SMALLINT
			,@maxBettype		SMALLINT
			,@remoteQuery		NVARCHAR(MAX)
			,@strMatchIds		VARCHAR(MAX)
			,@strEarlyBettypes	VARCHAR(MAX)
			,@strResourceIds	VARCHAR(MAX)
			,@matchidList		VARCHAR(MAX) = ''


	DECLARE @tmpLeagueIds  TABLE (LeagueId INT)
	DECLARE @tmpSporttypes  TABLE (Sporttype SMALLINT)
	DECLARE @tmpTicketStatus TABLE(Id TINYINT)
	DECLARE @tmpMatchStatus TABLE(Id TINYINT, EventStatus NVARCHAR(50))
	DECLARE @tmpQueueStatus TABLE(MatchId INT, IsCalculatingSingle TINYINT DEFAULT(0), IsCalculatingMP TINYINT DEFAULT(0))
	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsExistMarkedTicketParlay BIT DEFAULT(0))
	DECLARE @tmpMatchEsport TABLE (MatchId INT)
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
	DECLARE @tmpResultDetail TABLE (
		MatchId				INT
		,ResourceId			VARCHAR(20)
		,HomeValue			VARCHAR(50)
		,AwayValue			VARCHAR(50)
		,ResultStatusId		TINYINT
		,SettlementStatusId TINYINT
	)

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
		,IsNeutral						BIT
		,betstatus						NVARCHAR(50)
		,suspenderhalftime				NVARCHAR(50)
		,suspenderfulltime				NVARCHAR(50)
		,autosetting					TINYINT
		,autosettingforleague			TINYINT
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

		,IsExistMarkedTicket			BIT DEFAULT (0)
		,IsExistMarkedTicketParlay		BIT DEFAULT (0)
		,IsExistRunningBettypeSingle	BIT DEFAULT (0) -- exclude early bettype
		,IsExistRunningTicketAfterCompleted	BIT DEFAULT (0) -- after match completed

		,AutoPayoutStatus				TINYINT
		,IsExistsRunningInterval		BIT DEFAULT (0) --Apply for Basketball, Tennis, Badminton, E-sports, Cricket
		,IsPending						BIT DEFAULT (0)
	)

	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)
	
	CREATE TABLE #tmpAllParentChildMatch (MatchId INT, ParentId INT)

	SET @n = 2147483647
	
	IF @MatchCode <> ''
	BEGIN
		SELECT @TicketStatus = '0'
				,@MatchStatus = ''
				,@LeagueIds = ''
	END
	
	INSERT INTO @tmpSporttypes(Sporttype)
	SELECT	DISTINCT val
	FROM	dbo.f_SplitString(@Sporttypes, ',')
	OPTION (MAXRECURSION 0)

	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT	DISTINCT val
	FROM	dbo.f_SplitString(@LeagueIds, ',')
	OPTION (MAXRECURSION 0)

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

	IF ISNUMERIC(@MatchCode) = 1
	BEGIN
		SET @MatchId = CAST(@MatchCode AS INT)
	END

	IF @MatchCode <> ''
	BEGIN
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
			,IsNeutral
			,betstatus
			,suspenderhalftime
			,suspenderfulltime
			,autosetting
			,autosettingforleague
			,settlementstatus
			,childmatchtype
			,IsCalculated
			,IsMultiCaled
			,IsRefund
			,IsCalRefund
			,IsHalfTimeCal
			,AutoPayoutStatus
			,IsPending
		)
		SELECT	m.matchid
				,m.matchcode
				,m.LeagueId
				,m.sporttype
				,m.kickofftime
				,m.homeid
				,m.awayid
				,m.hthomescore
				,m.htawayscore
				,m.finalhomescore
				,m.finalawayscore
				,m.eventstatus
				,m.IsNeutral
				,m.betstatus
				,CASE mr.ConfirmHT 
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmHT)
				END
				,CASE mr.ConfirmFT
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmFT)
				END
				,ISNULL(m.AutoSetting, 0) AutoSetting
				,ISNULL(l.AutoSetting,0) AS AutoSettingForLeague
				,m.SettlementStatus
				,m.ChildMatchType
				,mr.calculate
				,mr.multiple
				,mr.refund
				,mr.calrefund
				,mr.IsHTCal
				,ap.StatusId
				,mr.isPending
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON m.leagueid = l.leagueid
			LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
				ON	m.matchid = mr.matchid
			OUTER APPLY (
					SELECT TOP 1 matchid, StatusId
					FROM DBPRO.bodb02.dbo.AutoPayoutResult WITH (NOLOCK)
					WHERE matchid = m.matchid
				)ap
		WHERE	(m.matchid = @MatchId OR m.matchcode LIKE + '%' + @MatchCode + '%')
				AND m.eventdate BETWEEN @FromDate AND @ToDate
				AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END -- dont get the child match of cricket
	END
	ELSE
	BEGIN
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
			,IsNeutral
			,betstatus
			,suspenderhalftime
			,suspenderfulltime
			,autosetting
			,autosettingforleague
			,settlementstatus
			,childmatchtype
			,IsCalculated
			,IsMultiCaled
			,IsRefund
			,IsCalRefund
			,IsHalfTimeCal
			,AutoPayoutStatus
			,IsPending
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
				,m.IsNeutral
				,m.betstatus
				,CASE mr.ConfirmHT 
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmHT)
				END
				,CASE mr.ConfirmFT
					WHEN 0 THEN ''
					ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmFT)
				END
				,ISNULL(m.AutoSetting, 0) AutoSetting
				,ISNULL(l.AutoSetting, 0) AS AutoSettingForLeague
				,m.SettlementStatus
				,m.ChildMatchType
				,mr.calculate
				,mr.multiple
				,mr.refund
				,mr.calrefund
				,mr.IsHTCal
				,ap.StatusId
				,mr.isPending
		FROM	dbo.match m WITH(NOLOCK)
			INNER JOIN @tmpLeagueIds tl 
				ON	m.leagueid = tl.LeagueId
			INNER JOIN dbo.League l WITH(NOLOCK)
				ON	m.leagueid = l.LeagueId
			LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
				ON	m.matchid = mr.matchid
			OUTER APPLY (
					SELECT TOP 1 matchid, StatusId
					FROM DBPRO.bodb02.dbo.AutoPayoutResult WITH (NOLOCK)
					WHERE matchid = m.matchid
				)ap
		WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
				AND (@Remark = 0 OR @Remark & m.SettlementStatus > 0)
				AND l.isTest = CASE WHEN @IsIncludeTest = 0 THEN 0 ELSE l.isTest END
				AND EXISTS (
					SELECT TOP 1 1
					FROM	@tmpMatchStatus s
					WHERE	m.eventstatus = CASE 
												WHEN s.Id IN (0, 7, 4, 9) THEN m.eventstatus
												ELSE s.EventStatus
											END
							AND 1 = CASE
										WHEN s.Id NOT IN (3,4,6,7) THEN 1
										WHEN s.Id = 3 AND m.kickofftime < GETDATE() THEN 1 -- kicked-off/in-play: 'Running' and have passed Kick-off Time.
										WHEN s.Id = 4 AND ISNULL(mr.calculate,0) = 0 
													  AND ISNULL(mr.calrefund,0) = 0
													  AND m.eventstatus IN ( 'running', 'closed')
													  THEN CASE WHEN mr.ConfirmFT > 0 THEN 1
																ELSE  CASE WHEN  DATEDIFF (MINUTE,  m.kickofftime, GETDATE() ) > 30 THEN 1
																			ELSE 0 
																	  END
															END
										WHEN s.Id = 6 AND m.betstatus NOT LIKE '%Refund%' THEN 1
										WHEN s.Id = 7 AND m.betstatus LIKE '%Refund%' THEN 1									
										ELSE 0
									END
				)
				AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END -- dont get the child match of cricket
	END

	--check auto setting
	IF (@AutoSetting > 0) AND @MatchCode = ''
	BEGIN
		DECLARE @DirectAutoPayout TINYINT
		SELECT @DirectAutoPayout = CASE WHEN @AutoSetting = 1 THEN 16 -- Auto payout only (Auto/Direct)
										WHEN @AutoSetting = 3 THEN 18 -- Auto payout and Instant Calc
										ELSE 0
									END
		DELETE m
		FROM #tmpMatchIds m
		--WHERE @AutoSetting & m.AutoSetting <> @AutoSetting
		WHERE 1 = 
				CASE 
					WHEN 16 & m.AutoSetting = 16 AND @AutoSetting IN (1,3) THEN 
						CASE WHEN @DirectAutoPayout & m.AutoSetting <> @DirectAutoPayout THEN 1 ELSE 0 END 
					ELSE 
						CASE WHEN @AutoSetting & m.AutoSetting <> @AutoSetting THEN 1 ELSE 0 END
				END
	END

	;WITH singlequeue 
	AS(
		SELECT	s.matchid
				,MIN(s.IsCalculating) AS IsCalculatingSingle
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	s.Starttime > DATEADD(MINUTE, -10, GETDATE())
				AND s.IsCalculating IN (0,1)
				AND s.SportType <> 1
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

	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId)
	SELECT	m.matchid, m.ParentId
	FROM	#tmpMatchIds t
		CROSS APPLY (
			SELECT	m.matchid, m.ParentId
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.sporttype = 50
					AND m.ChildMatchType = 200
					AND m.ParentID = t.matchid
		)m
	UNION ALL SELECT m.matchid, m.matchid FROM #tmpMatchIds m

	SELECT	@minBettype = MIN(bettype)
			,@maxBettype = MAX(bettype)
	FROM	dbo.f_Set_GetEarlyBettypes()

	INSERT INTO @tmpEarlyBettypeStatus(MatchId, isExistSingle, isRunningSingle, isWaitingSingle, isExistParlay, isRunningParlay, isWaitingParlay)
	SELECT	m.ParentId
			,MAX(b.isExistSingle)
			,MAX(b.IsRunningSingle)
			,MAX(b.IsWaitingSingle)
			,MAX(b.isExistParlay)
			,MAX(b.isRunningParlay)
			,MAX(b.isWaitingParlay)
	FROM	(
		SELECT TOP(@n) matchid, ParentId FROM #tmpAllParentChildMatch
	)m
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
			GROUP BY b.matchid, b.bettype
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
			GROUP BY bm.matchid, bm.bettype
		)b
		INNER JOIN dbo.f_Set_GetEarlyBettypes() f
			ON b.bettype = f.bettype
	GROUP BY m.ParentId
	OPTION(OPTIMIZE FOR (@n = 1))

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
			FROM  #tmpAllParentChildMatch m
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

	IF (@MatchStatus LIKE '%9%' AND EXISTS (SELECT TOP 1 1 FROM #tmpMatchIds m WHERE m.sporttype IN (2,5,9,43,50)	)) --interval Over
	BEGIN
		
		CREATE TABLE #RunningInterval ( MatchId INT, SportType TINYINT, ResourceId VARCHAR(20))

		INSERT INTO #RunningInterval ( MatchId, SportType, ResourceId )
		SELECT    MatchId , SportType, ResourceId
		FROM  #tmpMatchIds m
			CROSS APPLY (SELECT r.ResourceId 
						FROM DBPRO.bodb02.dbo.ResultDetail r WITH(NOLOCK)
						WHERE r.SettlementStatusID = 0
							AND r.ResultStatusID = 3
							AND r.ResourceID IN ('Q1','Q2','Q3','Q4','01','02','03','04','05')
							AND r.MatchId = m.matchid
							AND m.sporttype IN (2, 5)
												
						UNION ALL
						SELECT r.ResourceId 
						FROM DBPRO.bodb02.dbo.ResultDetailES r WITH(NOLOCK)
						WHERE r.SettlementStatusID = 0
							AND r.ResultStatusID = 3
							AND r.ResourceID IN ('M1','M2','M3','M4','M5','M6','M7','M8','M9')
							AND r.MatchId = m.matchid
							AND m.sporttype = 43
												
						UNION ALL
						SELECT r.ResourceId 
						FROM DBPRO.bodb02.dbo.ResultDetailOS r WITH(NOLOCK)
						WHERE r.SettlementStatusID = 0
							AND r.ResultStatusID = 3
							AND r.ResourceID IN ('0101','0102','0103','0104','0105','H1','A1','H2','A2')
							AND r.MatchId = m.matchid
							AND m.sporttype IN( 9, 50)
						)r
		WHERE m.IsExistRunningBettypeSingle =1 
			OR m.IsRunningEarlyBettypesSingle = 1

		 UPDATE m SET IsExistsRunningInterval = 1 
		 FROM #tmpMatchIds m
			INNER JOIN	 #RunningInterval i ON m.matchid = i.MatchId
			CROSS APPLY ( SELECT TOP 1 i.MatchId
							FROM dbo.bettrans b WITH(NOLOCK)
								INNER JOIN dbo.SettlementSpecialBettypeProfile sp  WITH(NOLOCK)
								ON b.bettype = sp.BetType AND (sp.Betid = 0 OR sp.BetID = b.BetID)
							WHERE sp.SportType = i.SportType
								AND sp.SettleType ='MNL'
								AND i.MatchId = b.matchid
								AND i.ResourceId = sp.ResourceID
			
					) b
		 DELETE FROM #tmpMatchIds WHERE  sporttype IN (2, 5, 9, 43, 50) AND IsExistsRunningInterval = 0
	END

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, m.matchid
	FROM	#tmpMatchIds m
		CROSS APPLY (
			SELECT	mt.TransId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt
	WHERE m.sporttype <> 50

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = m.HasMarkedSingle
				,IsExistMarkedTicketParlay = m.HasMarkedParlay
		FROM	@tmpMatchMarked mk
			INNER JOIN (
				SELECT	mt.matchId
						,CASE WHEN MIN(ISNULL(bm.IsParlay,0)) = 0 THEN 1 ELSE 0 END AS HasMarkedSingle
						,CASE WHEN MAX(ISNULL(bm.IsParlay,0)) = 1 THEN 1 ELSE 0 END AS HasMarkedParlay
				FROM	#tmpMarkedTransaction mt
					CROSS APPLY (
						SELECT	TOP (1) b.transid
								,b.refno
								,b.matchid
								,b.statusID
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	mt.transid = b.transid
					) b
					OUTER APPLY (
						SELECT TOP 1 1 IsParlay
						FROM	dbo.bettransm bm WITH(NOLOCK)
						WHERE	bm.refno = b.refno
								AND bm.statusid = 0
								AND b.matchid = 29
								AND bm.matchid = mt.matchId
					)bm
				WHERE	1 = CASE
								WHEN b.matchid <> 29 AND b.statusID = 0 THEN 1
								WHEN b.matchid = 29 AND bm.IsParlay = 1 THEN 1
								ELSE 0
							END
				GROUP BY mt.matchid
			) m
				ON m.matchId = mk.MatchId

		UPDATE m 
			SET IsExistMarkedTicket = t.IsExistMarkedTicket
				,IsExistMarkedTicketParlay = t.IsExistMarkedTicketParlay
		FROM	#tmpMatchIds m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId
	END

	IF @MatchCode = '' AND NOT EXISTS (SELECT TOP 1 1 FROM @tmpTicketStatus WHERE id = 0)
	BEGIN
		DELETE	m
		FROM	#tmpMatchIds m
		WHERE	NOT EXISTS (
			SELECT TOP 1 1
			FROM	@tmpTicketStatus t
			WHERE	1 = CASE
							WHEN t.Id = 0 THEN 1
							WHEN t.Id = 1 AND (m.IsExistMarkedTicket > 0 OR m.IsExistMarkedTicketParlay > 0) THEN 1 -- marked ticket
							WHEN t.Id = 2 AND m.IsExistEarlyBettypesSingle > 0 AND m.IsRunningEarlyBettypesSingle > 0 THEN 1 -- un-calculated early
							WHEN t.Id = 3 AND m.IsExistRunningBettypeSingle = 1 THEN 1 -- un-calculate single
							WHEN t.Id = 4 AND (ISNULL(m.IsCalculated,0) = 1 OR ISNULL(m.IsCalRefund,0) = 1) AND (ISNULL(m.IsMultiCaled,0) = 0 AND ISNULL(m.IsRefund,0) = 0) THEN 1 -- un-calculate parlay
							ELSE 0
						END
		)
	END
	
	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0))

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	m.matchid
	FROM	#tmpMatchIds m
	WHERE	m.eventstatus = 'completed'

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE m 
			SET IsExistRunningTicket = 1
		FROM	@tmpMatchCompleted m
			CROSS APPLY (
				SELECT	tmp.ParentId
				FROM	dbo.bettrans b WITH(NOLOCK)
					INNER JOIN #tmpAllParentChildMatch tmp ON b.MatchId = tmp.MatchId
					OUTER APPLY (
							SELECT TOP 1 mt.transId
							FROM	#tmpMarkedTransaction mt 
							WHERE	b.transid = mt.TransId
						)mt
				WHERE	tmp.ParentId = m.matchid
						AND b.statusID = 0
						AND mt.transId IS NULL
				GROUP BY tmp.ParentId
			)b

		UPDATE m 
			SET IsExistRunningTicketAfterCompleted = t.IsExistRunningTicket
		FROM	#tmpMatchIds m
			INNER JOIN @tmpMatchCompleted t
				ON	m.matchid = t.MatchId
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpMatchIds WHERE sporttype = 43)
	BEGIN
		SELECT @strMatchIds = ''
				,@strEarlyBettypes = ''
				,@remoteQuery = ''
				,@strResourceIds = ''
		
		SELECT @strEarlyBettypes = @strEarlyBettypes + CAST(bettype AS VARCHAR(20)) + ','
		FROM	dbo.f_Set_GetEarlyBettypes()

		SELECT @strMatchIds = @strMatchIds + CAST(MatchId AS VARCHAR(20)) + ','
		FROM	#tmpMatchIds
		WHERE	sporttype = 43

		SELECT @strResourceIds = @strResourceIds + '''' + f.ResourceID + '''' + ','
		FROM	dbo.f_Set_MajorRound (43) f
		
		SELECT	@strEarlyBettypes = LEFT(@strEarlyBettypes,LEN(@strEarlyBettypes) - 1)
				,@strMatchIds = LEFT(@strMatchIds, LEN(@strMatchIds) - 1)
				,@strResourceIds = LEFT(@strResourceIds, LEN(@strResourceIds) - 1)
				
		SET @remoteQuery = 'SELECT	DISTINCT o.matchid 
							FROM	DBPRO.bodb02.dbo.oddsES o WITH(NOLOCK)
							WHERE	o.matchid IN (' + @strMatchIds + ')
									AND bettype IN (' + @strEarlyBettypes + ')
									AND o.sporttype = 43'

		INSERT INTO @tmpMatchEsport (MatchId)
		EXECUTE sys.sp_executesql @remoteQuery
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
			,m.IsNeutral
			,m.betstatus
			,m.suspenderhalftime
			,m.suspenderfulltime
			,m.autosetting
			,m.autosettingforleague
			,m.settlementstatus
			,q.IsCalculatingSingle
			,q.IsCalculatingMP
			,m.IsCalculated
			,m.IsMultiCaled
			,m.IsRefund
			,m.IsCalRefund
			,m.IsHalfTimeCal
			,CASE
				WHEN m.IsExistEarlyBettypesSingle = 0 AND m.IsExistEarlyBettypesParlay = 0 AND (m.childmatchtype = 202 OR me.MatchId IS NOT NULL ) THEN 'No Ticket'
				WHEN m.IsExistEarlyBettypesSingle = 0 AND m.IsExistEarlyBettypesParlay = 0 THEN 'N/A'
				WHEN m.IsRunningEarlyBettypesSingle = 1 THEN 'Running'
				WHEN m.IsWaitingEarlyBettypesSingle = 1 THEN 'Waiting'
				WHEN m.IsExistEarlyBettypesSingle = 0 AND m.IsRunningEarlyBettypesParlay = 1 THEN 'Parlay Running'
				WHEN m.IsExistEarlyBettypesSingle = 0 AND m.IsWaitingEarlyBettypesParlay = 1 THEN 'Parlay Waiting'
				ELSE 'Completed'
			END AS EarlySettleStatus
			,m.IsExistRunningTicketAfterCompleted AS IsExistRunningTicket
			,m.IsExistMarkedTicket
			,m.IsExistMarkedTicketParlay
			,m.AutoPayoutStatus
	FROM	#tmpMatchIds m
		LEFT JOIN @tmpQueueStatus q
			ON	m.matchid = q.MatchId
		LEFT JOIN @tmpMatchEsport me
			ON	m.matchid = me.MatchId			  
	ORDER BY 
		 CASE 
				WHEN m.eventstatus = 'completed' AND m.IsExistRunningTicketAfterCompleted = 1 THEN 0
				WHEN m.eventstatus = 'running'	 THEN 1
				WHEN m.eventstatus = 'postponed' THEN 2
				WHEN m.eventstatus = 'internal'  THEN 3
				WHEN m.eventStatus = 'closed'	 THEN 4
				ELSE 99
			END
		, m.IsCalRefund
		, m.IsPending
		, m.kickofftime
		, m.sporttype
		, m.leagueid
		, m.matchcode
	
	SELECT @matchidList =  @matchidList + ',' + CAST(matchid AS VARCHAR(20))
	FROM #tmpMatchIds

	SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))

	EXEC DBPRO.bodb02.dbo.NAP_Set_ResultDetailSel
		@matchidList = @matchidList

END

GO