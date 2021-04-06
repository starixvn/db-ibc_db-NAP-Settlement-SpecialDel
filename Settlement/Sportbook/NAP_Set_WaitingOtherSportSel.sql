/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_WaitingOtherSportSel] 
	@MatchCode 		NVARCHAR(50) = ''
	, @LeagueIds	VARCHAR(MAX)
AS
/*
	Created: 20140103@Kathy
	Task: Get status for a match [Redmine:#134843] 
	DB: DBTXN/BODB02
	
	Revision:
		- 20200528@Kathy: Get status for a match [Redmine:#134843] 
		- 20200827@Louisa: Get external score [Redmine:#139979]
		- 20210205@Louisa: Cricket AIO [Redmine:#148870]
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]

	Param's explanation:  
		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @matchid		INT
		,@StartTime			DATETIME
		,@EndTime			DATETIME
		,@MinBettype		SMALLINT
		,@MaxBettype		SMALLINT
		,@n					INT 
		,@remoteQuery		NVARCHAR(MAX)
		,@strMatchIds		VARCHAR(MAX)
		,@strEarlyBettypes	VARCHAR(MAX)
		,@strResourceIds	VARCHAR(MAX)
		
	DECLARE @tmpLeagueIds TABLE(LeagueId INT)
	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsExistMarkedTicketParlay BIT DEFAULT(0))
	DECLARE @tmpMatchEsport TABLE (MatchId INT)
	DECLARE @tmpBettypeStatus TABLE(
		MatchId				INT
		,bettype			SMALLINT
		,isExistSingle		BIT DEFAULT(0)
		,isExistParlay		BIT DEFAULT(0)
		,isRunningSingle	BIT DEFAULT(0)
		,isWaitingSingle	BIT DEFAULT(0)
		,isRunningParlay	BIT DEFAULT(0)
		,isWaitingParlay	BIT DEFAULT(0)
	)

	DECLARE @tmpMatchIds TABLE (
		MatchId							INT
		,Sporttype						SMALLINT
		,EventStatus					NVARCHAR(50)
		,betstatus						NVARCHAR(50)
		,halftimehomescore 				INT
		,halftimeawayscore 				INT
		,finalhomescore					INT
		,finalawayscore					INT
		,IsCalculatingSingle 			TINYINT   -- NULL: no change, 0: waiting, 1: calculating, 2: completed
		,IsCalculatingMP 				TINYINT 
		,IsCalculated					BIT
		,IsMultiCaled					BIT
		,IsRefund						BIT
		,IsCalRefund					BIT
		,IsHalfTimeCal					BIT
		,childmatchtype					TINYINT
		,autosetting					TINYINT
		,autosettingforleague			TINYINT
		,settlementstatus				TINYINT
		,suspenderhalftime				NVARCHAR(50)
		,suspenderfulltime				NVARCHAR(50)
		
		
		,IsExistEarlyBettypesSingle		BIT DEFAULT (0)
		,IsExistEarlyBettypesParlay		BIT DEFAULT (0)
		,IsRunningEarlyBettypesSingle	BIT DEFAULT(0)
		,IsRunningEarlyBettypesParlay	BIT DEFAULT(0)
		,IsWaitingEarlyBettypesSingle	BIT DEFAULT(0)
		,IsWaitingEarlyBettypesParlay	BIT DEFAULT(0)
		,IsExistMarkedTicket			BIT DEFAULT(0)
		,IsExistMarkedTicketParlay		BIT DEFAULT(0)
		,IsExistRunningTicket			BIT DEFAULT(0)

		,AutoPayoutStatus				TINYINT
	)
	
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)

	SET @n = 2147483647
	SELECT @MatchCode = ISNULL(@MatchCode, '')
	
	INSERT INTO @tmpLeagueIds(LeagueId)
	SELECT	DISTINCT f.val
	FROM	dbo.f_SplitString(@LeagueIds, ',') f
	OPTION(MAXRECURSION 0)	

	IF ISNUMERIC(@MatchCode) = 1
		SET @matchid = CAST(@MatchCode AS INT)
	
	
	;WITH singlequeue AS (
		SELECT	matchid, MIN(IsCalculating) AS IsCalculating
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	Starttime > DATEADD(MINUTE, -100, GETDATE()) 
		GROUP BY matchid
	), parlayqueue AS (
		SELECT	p.matchid, MIN(IsCalculating) AS IsCalculating
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE	Starttime > DATEADD(MINUTE, -100, GETDATE())
		GROUP BY p.matchid
	)
	
	INSERT INTO @tmpMatchIds(MatchId
		,Sporttype
		,halftimehomescore					
		,halftimeawayscore					
		,finalhomescore					
		,finalawayscore					
		,IsCalculated
		,IsMultiCaled
		,IsRefund
		,IsCalRefund
		,IsHalfTimeCal
		,EventStatus
		,betstatus
		,IsCalculatingSingle
		,IsCalculatingMP
		,autosetting				
		,autosettingforleague	
		,settlementstatus	
		,suspenderhalftime
		,suspenderfulltime
		,AutoPayoutStatus
	)
	SELECT	m.matchid
			,m.sporttype
			,m.hthomescore
			,m.htawayscore
			,m.finalhomescore
			,m.finalawayscore
			,ISNULL(mr.calculate, 0) AS IsCalculated
			,ISNULL(mr.multiple, 0) AS IsMultiCaled
			,ISNULL(mr.refund, 0) AS IsRefund
			,ISNULL(mr.calrefund, 0) AS IsCalRefund
			,ISNULL(mr.IsHTCal, 0) AS IsHalfTimeCal
			,m.eventstatus
			,m.betstatus
			,tmp.IsCalculatingSingle
			,tmp.IsCalculatingMP
			,ISNULL(m.AutoSetting, 0) AS AutoSetting 
			,ISNULL(l.AutoSetting, 0) AS AutoSettingForLeague
			,m.SettlementStatus
			,CASE mr.ConfirmHT 
				WHEN 0 THEN ''
				ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmHT)
			END
			,CASE mr.ConfirmFT
				WHEN 0 THEN ''
				ELSE (SELECT username FROM CustDB.dbo.custInfo WITH(NOLOCK) WHERE custid = mr.ConfirmFT)
			END
			,ap.StatusId
	FROM (
		SELECT	ISNULL(s.matchid, p.matchid) AS MatchId
				,s.IsCalculating AS IsCalculatingSingle
				,p.IsCalculating AS IsCalculatingMP
		FROM	singlequeue s
			FULL OUTER JOIN parlayqueue p 
				ON	s.matchid = p.matchid
	) tmp
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON	tmp.MatchId = m.matchid
		INNER JOIN @tmpLeagueIds tl
			ON	m.leagueid = tl.LeagueId
		INNER JOIN dbo.League l WITH(NOLOCK)	
			ON m.leagueid = l.leagueid
		LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
			ON	m.matchid = mr.matchid
		OUTER APPLY (
					SELECT TOP 1 matchid, StatusId
					FROM dbo.AutoPayoutResult WITH (NOLOCK)
					WHERE matchid = m.matchid
				)ap
	WHERE	(@MatchCode = '' OR m.matchcode = @MatchCode OR m.matchid = @matchid)
		AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END -- dont get the child match of cricket
	
	CREATE TABLE #tmpAllParentChildMatch (MatchId INT, ParentId INT)
	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId)
	SELECT	m.matchid, m.ParentId
	FROM	@tmpMatchIds t
		CROSS APPLY (
			SELECT	m.matchid, m.ParentId
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.sporttype = 50
					AND m.ChildMatchType = 200
					AND m.ParentID = t.matchid
		)m
	UNION ALL SELECT m.matchid, m.matchid FROM @tmpMatchIds m
		
	SELECT	@minBettype = MIN(bettype)
			,@maxBettype = MAX(bettype)
	FROM	dbo.f_Set_GetEarlyBettypes()

	INSERT INTO @tmpBettypeStatus(MatchId, isExistSingle, isRunningSingle, isWaitingSingle, isExistParlay, isRunningParlay, isWaitingParlay)
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
	FROM	@tmpMatchIds m 
		INNER JOIN @tmpBettypeStatus b
			ON	m.matchid = b.MatchId

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, m.matchid
	FROM	@tmpMatchIds m
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
				ON m.matchid = mk.MatchId

		UPDATE m 
			SET IsExistMarkedTicket = t.IsExistMarkedTicket
				,IsExistMarkedTicketParlay = t.IsExistMarkedTicketParlay
		FROM	@tmpMatchIds m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId

	END

	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0))

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	m.matchid
	FROM	@tmpMatchIds m
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
							WHERE b.transid = mt.TransId
						)mt
				WHERE	tmp.ParentId = m.matchid
						AND b.statusID = 0
						AND mt.transId IS NULL
				GROUP BY tmp.ParentId
			)b

		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	@tmpMatchIds m
			INNER JOIN @tmpMatchCompleted t
				ON m.matchid = t.MatchId
	END
	
	IF EXISTS (SELECT TOP 1 1 FROM @tmpMatchIds WHERE sporttype = 43)
	BEGIN
		SELECT	@strMatchIds = ''
				,@strEarlyBettypes = ''
				,@remoteQuery = ''
				,@strResourceIds = ''
				
		SELECT @strEarlyBettypes = @strEarlyBettypes + CAST(bettype AS VARCHAR(20)) + ','
		FROM	dbo.f_Set_GetEarlyBettypes()

		SELECT @strMatchIds = @strMatchIds + CAST(MatchId AS VARCHAR(20)) + ','
		FROM	@tmpMatchIds
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

	SELECT	tmp.MatchId
			,tmp.Sporttype
			,tmp.EventStatus
			,tmp.betstatus
			,tmp.halftimehomescore
			,tmp.halftimeawayscore
			,tmp.finalhomescore
			,tmp.finalawayscore
			,tmp.IsCalculatingSingle
			,tmp.IsCalculatingMP
			,tmp.IsCalculated
			,tmp.IsMultiCaled
			,tmp.IsRefund
			,tmp.IsCalRefund
			,tmp.IsHalfTimeCal
			,tmp.autosetting
			,tmp.autosettingforleague
			,tmp.settlementstatus
			,tmp.suspenderhalftime
			,tmp.suspenderfulltime
			,CASE
				WHEN tmp.IsExistEarlyBettypesSingle = 0 AND tmp.IsExistEarlyBettypesParlay = 0 AND (tmp.childmatchtype = 202 OR me.MatchId IS NOT NULL ) THEN 'No Ticket'
				WHEN tmp.IsExistEarlyBettypesSingle = 0 AND tmp.IsExistEarlyBettypesParlay = 0 THEN 'N/A'
				WHEN tmp.IsRunningEarlyBettypesSingle = 1 THEN 'Running'
				WHEN tmp.IsWaitingEarlyBettypesSingle = 1 THEN 'Waiting'
				WHEN tmp.IsExistEarlyBettypesSingle = 0 AND tmp.IsRunningEarlyBettypesParlay = 1 THEN 'Parlay Running'
				WHEN tmp.IsExistEarlyBettypesSingle = 0 AND tmp.IsWaitingEarlyBettypesParlay = 1 THEN 'Parlay Waiting'
				ELSE 'Completed'
			END AS EarlySettleStatus
			,tmp.IsExistRunningTicket
			,tmp.IsExistMarkedTicket
			,tmp.IsExistMarkedTicketParlay
			,tmp.AutoPayoutStatus
	FROM	@tmpMatchIds tmp
		LEFT JOIN @tmpMatchEsport me
			ON tmp.MatchId = me.MatchId


	DECLARE @matchidList VARCHAR(MAX) = ''
	    
	SELECT @matchidList =  @matchidList + ',' + CAST(matchid AS VARCHAR(20))
	FROM @tmpMatchIds

	SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))
	    
	EXEC DBPRO.bodb02.dbo.NAP_Set_ResultDetailSel
		@matchidList = @matchidList

END
GO