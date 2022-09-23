/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingOtherSportSel] 
	@MatchIds	VARCHAR(MAX)
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
		- 20210729@Louisa: Auto Settle Cricket [Redmine:#154586]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210917@Kathy: write log if SP run too long
		- 20210906@Louisa: Get configuration from table SettlementResultTableSetting [Redmine:#160478]
		- 20211005@Louisa: Enhancement [Redmine:#162624]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220421@Louisa: Fix issue duplicate in MERGE statement [Redmine:#168346]
		- 20220620@Louisa: Extend Best Of Map Esports from M9 up to M30 [Redmine:#174252]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

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
		,@CheckDate			VARCHAR(10)
		,@SqlCommand		VARCHAR(MAX)
		,@IsCentral			BIT

	SET @StartTime = GETDATE()
	SET @n = 2147483647
	SET @CheckDate =  CONVERT(VARCHAR(10),DATEADD (DAY, -2, GETDATE()), 102)
		
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

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
		
		
		,IsExistEarlyBettypes			BIT DEFAULT (0)
		,IsExistEarlyBettypesParlay		BIT DEFAULT (0)
		,IsRunningEarlyBettypes			BIT DEFAULT(0)
		,IsRunningEarlyBettypesParlay	BIT DEFAULT(0)
		,IsWaitingEarlyBettypes			BIT DEFAULT(0)
		,IsWaitingEarlyBettypesParlay	BIT DEFAULT(0)
		,IsExistMarkedTicket			BIT DEFAULT(0)
		,IsExistMarkedTicketParlay		BIT DEFAULT(0)
		,IsExistRunningTicket			BIT DEFAULT(0)
		,IsExistRunningTicketParlay		BIT DEFAULT(0)

		,AutoPayoutStatus				TINYINT
		,IsMergedParlay					BIT DEFAULT(0)
		,BestOfMap						TINYINT
	)
	DECLARE @tmpQueueStatus TABLE(MatchId INT, IsCalculatingSingle TINYINT, IsCalculatingMP TINYINT, AutoPayoutStatus TINYINT)
	DECLARE @tmpAutoPayOutResultOS TABLE ( Matchid INT, StatusId TINYINT )
	
	CREATE TABLE #MatchIdList ( MatchId INT)
	CREATE INDEX CIX_matchid ON #MatchIdList (MatchId)

	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)
	CREATE TABLE #temp_match_parlay (ParentID INT, transid BIGINT, matchid INT, refno BIGINT, IsMergedParlay BIT)
	
	IF ISNULL(@MatchIds,'') <> ''
	BEGIN
		INSERT INTO #MatchIdList (MatchId)
		SELECT f.[value] from STRING_SPLIT(@MatchIds, ',') f
	END

	---- Match Auto
	SET @remoteQuery = 'SELECT  r.matchid, MAX(r.StatusId) AS StatusId
						FROM DBPRO.bodb02.dbo.AutoPayoutResultOS r WITH (NOLOCK)
						WHERE r.CreatedDate >= ''' + @CheckDate  +'''
						GROUP BY r.MatchId
					
						UNION ALL
						SELECT r.MatchId, r.StatusId
						FROM (
							SELECT ROW_NUMBER() OVER(PARTITION BY ap.matchid ORDER BY ap.CreatedDate DESC) AS rn, ap.MatchId, ap.StatusId
							FROM	DBPRO.bodb02.dbo.AutoPayoutResult ap WITH (NOLOCK)
							WHERE ap.CreatedDate  >= ''' + @CheckDate  +'''
							) r
						WHERE r.rn = 1
						'
									
	INSERT INTO @tmpAutoPayOutResultOS (MatchId, StatusId)
	EXECUTE sys.sp_executesql @remoteQuery

	;WITH singlequeue AS (
		SELECT	matchid, MIN(IsCalculating) AS IsCalculating
		FROM	dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE	( Starttime > DATEADD(MINUTE, -10, GETDATE()) OR s.IsCalculating IN (0,1) )
			AND s.SportType <> 1
		GROUP BY matchid
	), parlayqueue AS (
		SELECT	p.matchid, MIN(IsCalculating) AS IsCalculating
				,MAX(CASE WHEN IsCalculating = 1 THEN 1 ElSE 0 END) AS Running
		FROM	dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
		WHERE	Starttime > DATEADD(MINUTE, -10, GETDATE())
				OR p.IsCalculating IN (0,1)
		GROUP BY p.matchid
	)
	
	INSERT INTO @tmpQueueStatus(MatchId, IsCalculatingSingle, IsCalculatingMP )
	SELECT q.matchid, q.IsCalculatingSingle, q.IsCalculatingMP
	FROM ( SELECT ISNULL(s.matchid, p.matchid) AS matchid
				,s.IsCalculating AS IsCalculatingSingle
				,CASE WHEN p.Running = 1 THEN p.Running ELSE p.IsCalculating END AS IsCalculatingMP
			FROM	singlequeue s
				FULL OUTER JOIN parlayqueue p
					ON	s.matchid = p.matchid
		 ) q
	INNER JOIN #MatchIdList tmp 
		ON q.matchid = tmp.MatchId
	
	MERGE @tmpQueueStatus  TARGET
	USING (
		SELECT ap.MatchId, ap.StatusId
		FROM	 @tmpAutoPayOutResultOS ap
		INNER JOIN #MatchIdList tmp
			ON ap.matchid = tmp.MatchId
		) AS SOURCE ON TARGET.MatchId = SOURCE.matchid
	WHEN MATCHED THEN
		UPDATE SET AutoPayoutStatus = SOURCE.statusid
	WHEN NOT MATCHED BY TARGET THEN
		INSERT (MatchId, AutoPayoutStatus)
		VALUES (SOURCE.MatchId, SOURCE.statusid);
	
	SELECT	@minBettype = MIN(bettype)
			,@maxBettype = MAX(bettype)
	FROM	dbo.f_Set_GetEarlyBettypes()
	
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
		,IsMergedParlay
		,BestOfMap
	)
	SELECT DISTINCT	m.matchid
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
			,q.IsCalculatingSingle
			,q.IsCalculatingMP
			,ISNULL(m.AutoSetting, ISNULL(l.AutoSetting, 0)) AS AutoSetting 
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
			,q.AutoPayoutStatus
			,f.IsMergedParlay
			,mr.BestOfMap
	FROM  dbo.match m WITH(NOLOCK)	
		INNER JOIN @tmpQueueStatus q
			ON	m.matchid = q.MatchId
		INNER JOIN dbo.League l WITH(NOLOCK)	
			ON m.leagueid = l.leagueid
		LEFT JOIN dbo.match_remark mr WITH(NOLOCK)
			ON	m.matchid = mr.matchid
		OUTER APPLY(
				SELECT	ss.IsMergedParlay
				FROM	dbo.SettlementResultTableSetting ss WITH(NOLOCK)
				WHERE ss.Sporttype = m.sporttype
			)f
	WHERE m.sporttype <> 1
		AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END -- dont get the child match of cricket
	
	CREATE TABLE #tmpAllParentChildMatch (MatchId INT, ParentId INT, IsMergedParlay BIT DEFAULT(0))
	INSERT INTO #tmpAllParentChildMatch (MatchId, ParentId, IsMergedParlay)
	SELECT	m.matchid, m.ParentId, t.IsMergedParlay
	FROM	@tmpMatchIds t
		CROSS APPLY (
			SELECT	m.matchid, m.ParentId
			FROM	dbo.match m WITH(NOLOCK)
			WHERE	m.sporttype = 50
					AND m.ChildMatchType = 200
					AND m.ParentID = t.matchid
		)m
	UNION ALL SELECT m.matchid, m.matchid, m.IsMergedParlay FROM @tmpMatchIds m
	
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
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
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
					AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
					AND bm.statusID NOT IN (101, 102)
					AND bm.bettype BETWEEN @minBettype AND @maxBettype
			GROUP BY bm.matchid, bm.bettype
		)b
		INNER JOIN dbo.f_Set_GetEarlyBettypes() f
			ON b.bettype = f.bettype
	GROUP BY m.ParentId
	OPTION(OPTIMIZE FOR (@n = 1))

	UPDATE m
		SET  IsExistEarlyBettypes = b.isExistSingle
			,IsExistEarlyBettypesParlay = b.isExistParlay
			,IsRunningEarlyBettypes = b.isRunningSingle
			,IsRunningEarlyBettypesParlay = b.isRunningParlay
			,IsWaitingEarlyBettypes = b.isWaitingSingle
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

	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0), IsExistRunningTicketParlay BIT DEFAULT(0))

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	m.matchid
	FROM	@tmpMatchIds m
	WHERE	m.eventstatus = 'completed'

	IF @@ROWCOUNT <> 0
	BEGIN
		-- single
		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	@tmpMatchCompleted m
			CROSS APPLY (
				SELECT 1 AS IsExistRunningTicket
				FROM (
						SELECT	tmp.ParentId, b.transid, tmp.MatchId
						FROM	dbo.bettrans b WITH(NOLOCK)
							INNER JOIN #tmpAllParentChildMatch tmp 
								ON	b.MatchId = tmp.MatchId
						WHERE	b.matchid = m.MatchId
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
								AND b.statusID = 0
								AND b.bettype NOT BETWEEN 801 AND 806 -- Metric Gaming
								AND b.bettype <> 38 -- BetBuilder
					) b
					OUTER APPLY (
						SELECT TOP 1 mt.transId
						FROM	#tmpMarkedTransaction mt 
						WHERE	b.transid = mt.TransId
								AND b.MatchId = mt.matchId
								
					)mt
				WHERE	mt.transId IS NULL
				GROUP BY b.ParentId
			) t

		-- parlay
		INSERT INTO #temp_match_parlay (ParentID, transid, matchid, refno, IsMergedParlay)
		SELECT	tmp.ParentId, 0, tmp.MatchId, bm.refno, tmp.IsMergedParlay
		FROM @tmpMatchCompleted m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.MatchId = bm.matchid
			INNER JOIN #tmpAllParentChildMatch tmp	ON	bm.matchid = tmp.MatchId
		WHERE	bm.statusID = 0
			AND 1 = CASE 
						WHEN m.IsExistRunningTicket = 0
								AND tmp.IsMergedParlay = 1 THEN 1
						WHEN tmp.IsMergedParlay = 0 THEN 1
					END
		
		IF EXISTS (SELECT TOP 1 1 FROM #temp_match_parlay)
		BEGIN
			UPDATE   t
				SET transid = b.transid
			FROM   #temp_match_parlay  t
				INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
			
			UPDATE	m 
				SET IsExistRunningTicket = CASE WHEN t.IsMergedParlay = 1 AND m.IsExistRunningTicket = 0 THEN t.IsExistRunningTicketParlay ELSE m.IsExistRunningTicket END
					,IsExistRunningTicketParlay = t.IsExistRunningTicketParlay
			FROM	@tmpMatchCompleted m
					CROSS APPLY (
								SELECT 1 AS IsExistRunningTicketParlay
										,MAX(CASE WHEN b.IsMergedParlay = 1 THEN 1 ELSE 0 END) AS IsMergedParlay
								FROM (
										SELECT	ParentId, transid, MatchId, p.IsMergedParlay
										FROM	#temp_match_parlay p
										WHERE p.matchid = m.MatchId
									) b
									OUTER APPLY (
										SELECT TOP 1 mt.transId
										FROM	#tmpMarkedTransaction mt 
										WHERE	b.transid = mt.TransId
												AND b.MatchId = mt.matchId
									)mt
									WHERE	mt.transId IS NULL
									GROUP BY b.ParentId
								) t
			--WHERE m.IsExistRunningTicket = 0
		END
				
		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
				,IsExistRunningTicketParlay = t.IsExistRunningTicketParlay
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
			,tmp.IsExistEarlyBettypes
			,tmp.IsExistEarlyBettypesParlay
			,CASE WHEN me.matchid IS NOT NULL THEN 1 ELSE 0 END AS IsOpenOdds 
			,tmp.IsRunningEarlyBettypes
			,tmp.IsMergedParlay
			,tmp.IsRunningEarlyBettypesParlay
			,tmp.IsRunningEarlyBettypesParlay
			,tmp.IsWaitingEarlyBettypes
			,tmp.IsWaitingEarlyBettypesParlay
			,tmp.IsExistRunningTicket
			,tmp.IsExistRunningTicketParlay
			,tmp.IsExistMarkedTicket
			,tmp.IsExistMarkedTicketParlay
			,tmp.AutoPayoutStatus
			,tmp.BestOfMap
	FROM	@tmpMatchIds tmp
		LEFT JOIN @tmpMatchEsport me
			ON tmp.MatchId = me.MatchId

	DROP TABLE #tmpMarkedTransaction

	SET @EndTime = GETDATE()
	IF DATEDIFF(MILLISECOND, @StartTime, @EndTime) > 5000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_WaitingOtherSportSel @MatchIds =''' + ISNULL(@MatchIds,'')
		INSERT INTO dbo.SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END

END
GO