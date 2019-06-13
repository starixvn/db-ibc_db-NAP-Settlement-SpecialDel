/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingSel] 
	@MatchCode 		NVARCHAR(50) = ''
	, @SportType 	SMALLINT = 0
	, @LeagueId 	INT = 0 -- 0 for ALL Leagues
AS
/*
	Created: 20140103@Kathy
	Task: get status for a match
	DB: DBTXN/BODB02
	
	Revision:
		- 20140419@Lukas: reduce data return by excluding old matches
		- 20140421@Kathy: Directly get IsExistFGLG value from bettrans (not use NAP_Set_MatchBetStatusSel)
		- 20140506@Kathy: get HT FGLG status 
		- 20140711@Kathy: get Penalty Shootout status
		- 20141007@Jamie: Get Tennis in new table [Redmine: #23034]
		- 20150420@Jamie: Betradar phase II [Readmine:#27212]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160805@Kathy: Write log duration
		- 20160811@Patrick: Rearrange code & remove link server to DBPRO
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20161118@Kathy: Changes on Auto Settlement [Redmine:#67328]
		- 20161222@Kathy: Check match in queue in 10mins instead of 1 hour [Redmine:68890]
		- 20160509@Kathy: Fast Market integration [Remine:#56367]
		- 20170208@Bobby: Correct IsMissingAutoResult case [Remine:#67952]
		- 20170215@Kathy: Basketball All-in-One [Redmine:#71372]
		- 20170613@Kathy: Early Settlement [Redmine:#77835]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180611@Kaden: Add Blinking Color for Disabled Auto Cal FM Matches [Redmine:#96018]
		- 20181002@Kathy: Add New Status "Result Pending" and "Under Settlement" [Redmine:#102028]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190610@Kathy: Exclude checking running BetBuilder tickets [Redmine:#114877]
	
	Param's explanation:  
		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @matchid INT, @StartTime DATETIME, @EndTime	DATETIME, @SqlCommand VARCHAR(MAX)
		,@MinBettype SMALLINT, @MaxBettype SMALLINT,@isSettingByProfile BIT = 0
		
	SELECT @MatchCode = ISNULL(@MatchCode, ''), @LeagueId = ISNULL(@LeagueID, 0), @SportType = ISNULL(@SportType, 0)

	IF ISNUMERIC(@MatchCode) = 1
		SET @matchid = CAST(@MatchCode AS INT)
	
	DECLARE @TempMatch TABLE (MatchId INT
		,SingleStatus 					INT
		,ParlayStatus 					INT
		,IsSingle 						BIT
		,IsMixParlay 					BIT
		,IsExistFGLG 					BIT
		,IsExistHTFGLG 					BIT
		,SettlementStatusID 			TINYINT
		,IsExistAutoBettypes 			BIT
		,IsExistAutoBettypesParlay 		BIT
		,IsRunningAutoBettypes			BIT
		,IsRunningAutoBettypesParlay	BIT
		
		,IsWaitingAutoBettypes			BIT
		,IsWaitingAutoBettypesParlay	BIT
		
		,IsMissingAutoResult			BIT
		,IsExistFastMarket				BIT
		,IsRunningFastMarket			BIT
		,IsExistFastMarketResult		BIT
		,IsExistEarlyBettypes 			BIT
		,IsExistEarlyBettypesParlay 	BIT
		,IsRunningEarlyBettypes			BIT
		,IsRunningEarlyBettypesParlay	BIT
		,IsExistMarkedTicket			BIT
		,IsExistRunningTicket			BIT
	)
	
	CREATE TABLE #tblBettype (bettype SMALLINT PRIMARY KEY, ResourceId VARCHAR(20), GroupId SMALLINT, IsFGLG BIT)
	
	CREATE TABLE #tblResultDetail (matchid INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultStatusID TINYINT, SettlementStatusID TINYINT)
	
	CREATE INDEX IX_ResultDetail ON #tblResultDetail (matchid, ResourceId)
	
	CREATE TABLE #tblBetStatus (matchid INT, bettype SMALLINT, isRunning INT, IsWaiting INT, groupId TINYINT ,IsParlay	 BIT, IsFGLG BIT)
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
	BEGIN
		SELECT @isSettingByProfile = 1
	END
	
	;WITH SingleTicket AS (
		SELECT matchid, MIN(IsCalculating) AS IsCalculating
		FROM dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
			AND (sporttype = @sporttype OR @sporttype = 0)
			AND (leagueid = @leagueid OR @leagueId = 0)
		GROUP BY matchid 
	), ParlayTicket AS (
		SELECT p.matchid, MIN(IsCalculating) AS IsCalculating
		FROM dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK)
				ON p.matchid = m.matchid
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
			AND (m.sporttype = @sporttype OR @sporttype = 0)
			AND (m.leagueid = @leagueid OR @leagueId = 0)
		GROUP BY p.matchid 
	)
	
	INSERT INTO @TempMatch(MatchId, SingleStatus, ParlayStatus, IsSingle, IsMixParlay, IsExistFGLG, IsExistHTFGLG
		, IsExistAutoBettypes, IsExistAutoBettypesParlay, IsRunningAutoBettypes, IsRunningAutoBettypesParlay
		, IsWaitingAutoBettypes ,IsWaitingAutoBettypesParlay
		, IsMissingAutoResult , IsExistFastMarket, IsRunningFastMarket, IsExistFastMarketResult, IsExistEarlyBettypes, IsExistEarlyBettypesParlay, IsRunningEarlyBettypes, IsRunningEarlyBettypesParlay
		, IsExistMarkedTicket, IsExistRunningTicket
	)
	SELECT ISNULL(sg.matchid, pl.matchid) AS MatchId
		, sg.IsCalculating AS SingleStatus
		, pl.IsCalculating AS ParlayStatus
		, CAST(ISNULL(sg.IsCalculating, 0) AS BIT) AS IsSingle
		, CAST(ISNULL(pl.IsCalculating, 0) AS BIT) AS IsMixParlay
		, CONVERT(BIT, 0) AS IsExistFGLG
		, CONVERT(BIT, 0) AS IsExistHTFGLG
		, 0 AS IsExistAutoBettypes
		, 0 AS IsExistAutoBettypesParlay
		, 0 AS IsRunningAutoBettypes
		, 0 AS IsRunningAutoBettypesParlay
		
		, 0 AS IsWaitingAutoBettypes 
		, 0 AS IsWaitingAutoBettypesParlay 
		
		, 0 AS IsMissingAutoResult
		, 0 AS IsExistFastMarket
		, 0 AS IsRunningFastMarket
		, 0 AS IsExistFastMarketResult
		, 0 AS IsExistEarlyBettypes
		, 0 AS IsExistEarlyBettypesParlay
		, 0 AS IsRunningEarlyBettypes
		, 0 AS IsRunningEarlyBettypesParlay
		, 0 AS IsExistMarkedTicket
		, 0 AS IsExistRunningTicket
	FROM SingleTicket sg
		FULL OUTER JOIN ParlayTicket pl ON sg.matchid = pl.matchid
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tblBettype (bettype, ResourceId, GroupId,IsFGLG)
		SELECT	BetType
				,CASE 
					WHEN BetType = 22 THEN '160__'
					WHEN BetType IN (160,164,169,180,216) OR GroupId = 9 THEN CAST(BetType AS VARCHAR(20)) + '__'
					ELSE CAST(BetType AS VARCHAR(20))
				END AS ResourceId
				,GroupId
				,IsFGLG
		FROM	dbo.f_Set_GetGroupBettypes()
		WHERE	GroupId IN (3,4,8,9) OR IsUsedGoalRecordValue = 1
		UNION ALL
		SELECT	bettype
				,'' AS ResourceId -- not used for BAIO
				,10 AS GroupId
				, 0 AS IsFGLG
		FROM	dbo.f_Set_GetEarlyBettypes()
		
		SELECT @MinBettype = MIN(bettype)
			,@MaxBettype = MAX(bettype)
		FROM #tblBettype
		
		IF @Sporttype IN (0, 1, 2, 5)
		BEGIN
			INSERT INTO #tblResultDetail(matchid, ResourceId, HomeValue, AwayValue, ResultStatusID, SettlementStatusID)
			SELECT	r.MatchId, r.ResourceId, r.HomeValue, r.AwayValue, r.ResultStatusID, r.SettlementStatusID
			FROM	DBPRO.bodb02.dbo.ResultDetail r WITH (NOLOCK)
				INNER JOIN @TempMatch t
					ON r.matchid = t.MatchId
			
			IF @Sporttype IN (0,1)	
				UPDATE	m
					SET SettlementStatusID = rs.SettlementStatusID
						,IsExistFastMarketResult = rs.IsExistFastMarketResult
				FROM	@TempMatch m
					INNER JOIN (
						SELECT	r.matchid
							,MIN(CASE WHEN bt.groupId = 8 THEN ISNULL(r.SettlementStatusID,0) ELSE NULL END) AS SettlementStatusID
							,MAX(CASE WHEN bt.groupId = 9 THEN 1 ELSE 0 END) AS IsExistFastMarketResult
						FROM #tblResultDetail r
							INNER JOIN #tblBettype bt
								ON r.ResourceId LIKE bt.ResourceId
						WHERE bt.GroupId IN (8,9)
						GROUP BY r.matchid
					) rs
						ON m.MatchId = rs.matchId
		END
		
		INSERT INTO #tblBetStatus (matchid, bettype, isRunning,IsWaiting, groupId, IsParlay,IsFGLG)
		SELECT  b.matchid, b.bettype, MAX(isRunning),MAX(isWaiting), bt.GroupId, 0,bt.IsFGLG
		FROM	#tblBettype bt
			INNER JOIN
			(
				SELECT	b.matchid, b.bettype
					, SUM(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) isRunning
					, SUM(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) isWaiting
					
				FROM	dbo.bettrans b WITH (NOLOCK)
				WHERE	EXISTS (SELECT TOP 1 1 FROM @TempMatch t WHERE t.matchid = b.matchid)
						AND b.statusID NOT BETWEEN 101 AND 102
						AND b.bettype BETWEEN @MinBettype AND @MaxBettype
				GROUP BY b.matchid, b.bettype
			)b
				ON b.bettype = bt.bettype
		GROUP BY b.matchid, b.bettype, bt.GroupId,bt.IsFGLG
		
		INSERT INTO #tblBetStatus (matchid, bettype, isRunning,IsWaiting, groupId, IsParlay,IsFGLG)
		SELECT  bm.matchid, bm.bettype, MAX(bm.isRunning),MAX(bm.IsWaiting), bt.GroupId, 1,bt.IsFGLG
		FROM	#tblBettype bt
			INNER JOIN
				(
					SELECT	bm.matchid, bm.bettype
						, SUM(CASE WHEN bm.statusID = 0 THEN 1 ELSE 0 END) isRunning
						, SUM(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) IsWaiting
					FROM	dbo.bettransm bm WITH (NOLOCK)
					WHERE	EXISTS (SELECT TOP 1 1 FROM @TempMatch t WHERE t.matchid = bm.matchid)
							AND bm.statusID NOT BETWEEN 101 AND 102
							AND bm.bettype BETWEEN @MinBettype AND @MaxBettype
					GROUP BY bm.matchid, bm.bettype
				)bm
				ON bm.bettype = bt.bettype
		GROUP BY bm.matchid, bm.bettype, bt.GroupId,bt.IsFGLG

		;WITH cteBetStatus
		AS(
			SELECT matchid
				,MAX(CASE WHEN groupId IN (1,3) AND IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistHTFGLG
				,MAX(CASE WHEN groupId IN (2,4) AND IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistFGLG
				
				,MAX(CASE WHEN groupId = 8 AND IsParlay = 0 THEN 1 ELSE 0 END) AS IsExistAutoBettypes
				,MAX(CASE WHEN groupId = 8 AND IsParlay = 1 THEN 1 ELSE 0 END) AS IsExistAutoBettypesParlay
				
				,MAX(CASE WHEN groupId = 8 AND IsParlay = 0 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningAutoBettypes
				,MAX(CASE WHEN groupId = 8 AND IsParlay = 1 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningAutoBettypesParlay
				
				,MAX(CASE WHEN groupId = 8 AND IsParlay = 0 AND isWaiting > 0 THEN 1 ELSE 0 END) AS IsWaitingAutoBettypes
				,MAX(CASE WHEN groupId = 8 AND IsParlay = 1 AND isWaiting > 0 THEN 1 ELSE 0 END) AS IsWaitingAutoBettypesParlay
				
				,MAX(CASE WHEN groupId = 9 AND IsParlay = 0 THEN 1 ELSE 0 END) AS IsExistFastMarket
				,MAX(CASE WHEN groupId = 9 AND IsParlay = 0 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningFastMarket
				,MAX(CASE WHEN groupId = 10 AND IsParlay = 0 THEN 1 ELSE 0 END) AS IsExistEarlyBettypes
				,MAX(CASE WHEN groupId = 10 AND IsParlay = 1 THEN 1 ELSE 0 END) AS IsExistEarlyBettypesParlay
				,MAX(CASE WHEN groupId = 10 AND IsParlay = 0 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypes
				,MAX(CASE WHEN groupId = 10 AND IsParlay = 1 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypesParlay
			FROM #tblBetStatus
			GROUP BY matchid
		)
		UPDATE t
		SET IsExistFGLG = CASE WHEN tt.IsExistFGLG > 0 THEN 1 ELSE 0 END
			,IsExistHTFGLG = CASE WHEN tt.IsExistHTFGLG > 0 THEN 1 ELSE 0 END
			,IsExistAutoBettypes = CASE WHEN tt.IsExistAutoBettypes > 0 THEN 1 ELSE 0 END
			,IsExistAutoBettypesParlay = CASE WHEN tt.IsExistAutoBettypesParlay > 0 THEN 1 ELSE 0 END
			,IsRunningAutoBettypes = CASE WHEN tt.IsRunningAutoBettypes > 0 THEN 1 ELSE 0 END
			,IsRunningAutoBettypesParlay = CASE WHEN tt.IsRunningAutoBettypesParlay > 0 THEN 1 ELSE 0 END
			
			,IsWaitingAutoBettypes = CASE WHEN tt.IsWaitingAutoBettypes > 0 THEN 1 ELSE 0 END
			,IsWaitingAutoBettypesParlay = CASE WHEN tt.IsWaitingAutoBettypesParlay >  0 THEN 1 ELSE 0 END
			
			,IsExistFastMarket = CASE WHEN tt.IsExistFastMarket > 0 THEN 1 ELSE 0 END
			,IsRunningFastMarket = CASE WHEN tt.IsRunningFastMarket > 0 THEN 1 ELSE 0 END
			,IsExistEarlyBettypes = CASE WHEN tt.IsExistEarlyBettypes > 0 THEN 1 ELSE 0 END
			,IsExistEarlyBettypesParlay = CASE WHEN tt.IsExistEarlyBettypesParlay > 0 THEN 1 ELSE 0 END
			,IsRunningEarlyBettypes = CASE WHEN tt.IsRunningEarlyBettypes > 0 THEN 1 ELSE 0 END
			,IsRunningEarlyBettypesParlay = CASE WHEN tt.IsRunningEarlyBettypesParlay > 0 THEN 1 ELSE 0 END
		FROM @TempMatch t
		INNER JOIN cteBetStatus tt ON t.MatchId = tt.MatchId	
		
		UPDATE m
			SET IsMissingAutoResult = CASE WHEN t.MissingAutoResult > 0 THEN 1 ELSE 0 END
		FROM @TempMatch m
			INNER JOIN (
				SELECT  b.matchid, COUNT(1) MissingAutoResult
				FROM	#tblBetStatus b
					INNER JOIN #tblBettype c
						ON b.bettype = c.bettype
				WHERE	b.IsParLay = 1		
						AND NOT EXISTS (SELECT TOP 1 1 FROM #tblResultDetail WHERE b.matchid = MatchId AND ResourceId LIKE c.ResourceId)
						AND c.GroupId = 8
				GROUP BY b.matchid
		) t
			ON m.matchid = t.matchid
	END

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT PRIMARY KEY, matchId INT)

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, mt.matchid
	FROM	@TempMatch m
		CROSS APPLY (
			SELECT	mt.TransId, mt.MatchId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction
	
	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = 1
		FROM	@tmpMatchMarked mk
			INNER JOIN (
				SELECT	mt.matchId
				FROM	#tmpMarkedTransaction mt
					CROSS APPLY (
						SELECT	TOP (1) b.transid
						FROM	dbo.bettrans b WITH(NOLOCK)
						WHERE	mt.transid = b.transid
								AND b.statusID = 0
					) b
				GROUP BY mt.matchid
			) m
				ON m.matchid = mk.MatchId

		UPDATE m 
			SET IsExistMarkedTicket = t.IsExistMarkedTicket
		FROM	@TempMatch m
			INNER JOIN @tmpMatchMarked t
				ON m.matchid = t.MatchId

	END

	DECLARE @tmpMatchCompleted TABLE (MatchId INT, IsExistRunningTicket BIT DEFAULT (0))

	INSERT INTO @tmpMatchCompleted (MatchId)
	SELECT	t.matchid
	FROM	@TempMatch t
		INNER JOIN dbo.match m WITH(NOLOCK)
			ON t.MatchId = m.matchid
	WHERE	m.eventstatus = 'completed'

	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE m 
			SET IsExistRunningTicket = 1
		FROM	@tmpMatchCompleted m
			CROSS APPLY (
				SELECT	b.matchid
				FROM	dbo.bettrans b WITH(NOLOCK)
					OUTER APPLY (
						SELECT TOP 1 mt.transId
						FROM	#tmpMarkedTransaction mt 
						WHERE b.transid = mt.TransId
					)mt
				WHERE	b.matchid = m.matchid
						AND b.statusID = 0
						AND b.bettype NOT BETWEEN 801 AND 806 -- Metric Gaming
						AND b.bettype <> 38 -- BetBuilder
						AND mt.transId IS NULL
				GROUP BY b.matchid
			)b

		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	@TempMatch m
			INNER JOIN @tmpMatchCompleted t
				ON m.matchid = t.MatchId
	END
	
	SELECT m.matchid, m.leagueid, m.homeid, m.awayid, m.matchcode, m.finalhomescore, m.finalawayscore
		, m.betstatus, m.sporttype, m.goalrecord
		, hthomescore AS HalfTimeHomeScore
		, htawayscore AS HalfTimeAwayScore
		, ISNULL(mr.calculate, 0) AS IsCalculated
		, ISNULL(mr.multiple, 0) AS IsMultiCaled
		, ISNULL(mr.refund, 0) AS IsRefund
		, ISNULL(mr.calrefund, 0) AS IsCalRefund
		, m.eventstatus
		, ISNULL(m.isNeutral, CONVERT(BIT, 0)) AS IsNeutral
		, ISNULL(mr.IsHTCal, 0) AS IsHalfTimeCal
		, ISNULL(m.SettlementStatus, 0) AS SettlementStatus
		, ISNULL(m.AutoSetting, 0) AS AutoSetting
		, IsExistFGLG
		, IsExistHTFGLG
		, tm.SingleStatus AS IsCalculatingSingle
		, tm.ParlayStatus AS IsCalculatingMP
		, CASE WHEN  tm.IsExistAutoBettypes = 0 AND tm.IsExistAutoBettypesParlay = 0 THEN 'N/A'
				WHEN tm.IsRunningAutoBettypes = 1 THEN 'Running'
				WHEN tm.IsWaitingAutoBettypes = 1 THEN 'Waiting'
				WHEN IsExistAutoBettypes = 0  AND tm.IsRunningAutoBettypesParlay = 1 THEN 'Parlay Running'
				WHEN IsExistAutoBettypes = 0  AND tm.IsWaitingAutoBettypesParlay = 1 THEN 'Parlay Waiting'
				WHEN (tm.IsExistAutoBettypes > 0 AND tm.IsRunningAutoBettypes = 0)
					OR (tm.IsExistAutoBettypes = 0 AND tm.IsExistAutoBettypesParlay > 0 AND tm.IsRunningAutoBettypesParlay = 0) THEN 'Completed'				
				ELSE '' END AS AutoSettleResultStatus
		, CASE
			WHEN tm.IsExistFastMarket = 0 AND tm.IsExistFastMarketResult = 0 THEN 'N/A'
			WHEN tm.IsExistFastMarket = 0 AND tm.IsExistFastMarketResult = 1 THEN 'No Ticket'
			WHEN tm.IsRunningFastMarket > 0 THEN 'Running'
			ELSE 'Completed'
		END AS AutoSettleFastMarket
		, CASE
			WHEN tm.IsExistEarlyBettypes = 0 AND tm.IsExistEarlyBettypesParlay = 0 THEN 'N/A'
			WHEN tm.IsRunningEarlyBettypes > 0 THEN 'Running'
			WHEN tm.IsExistEarlyBettypes = 0 AND tm.IsRunningEarlyBettypesParlay > 0 THEN 'Parlay Running'
			ELSE 'Completed'
		END AS EarlySettleStatus
		,tm.IsExistMarkedTicket
		,tm.IsExistRunningTicket
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN @TempMatch tm ON m.matchid = tm.matchid
		LEFT JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
	WHERE m.sporttype = @sporttype
		AND (@LeagueId = 0 OR m.leagueid = @LeagueId)
		AND (@matchcode = '' OR (m.matchid = @matchid OR m.matchcode = @matchcode))
	
		
		
	-- Get TENNIS, BASKETBALL RESULT  
	IF @isSettingByProfile = 1
    BEGIN
	    DECLARE @matchidList VARCHAR(MAX) = ''
	    
	    SELECT @matchidList =  @matchidList + ',' + CAST(matchid AS VARCHAR(20))
	    FROM @TempMatch
	    SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))
	    
		EXEC DBPRO.bodb02.dbo.NAP_Set_MatchSel_ResultDetail 
					@matchidList = @matchidList
					,@Sporttype = @Sporttype  
    END
    ELSE IF @SportType IN (0,1,2,5)
		SELECT MatchId
			, ResourceId
			, HomeValue
			, AwayValue
			, ResultStatusID
			, SettlementStatusID
		FROM #tblResultDetail rs
		WHERE rs.MatchId IN (SELECT t.MatchId FROM @TempMatch t)
			AND (ResourceId LIKE '0[0-5]' -- Tennis
					OR ResourceId LIKE 'Q[1-4]' OR ResourceId = 'OT' -- Basketball: 00, 01, Q1, Q2, Q3, Q4, OT
				)
	ELSE
		SELECT MatchId
			, ResourceId
			, HomeValue
			, AwayValue
			, ResultStatusID
			, SettlementStatusID
		FROM #tblResultDetail rs
		WHERE 1 = 0

	SET @EndTime = GETDATE()
	IF DATEDIFF(MILLISECOND, @StartTime, @EndTime) > 1000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_WaitingSel @MatchCode =''' + ISNULL(@MatchCode,'') + ''', @SportType = ' + CONVERT(VARCHAR(10),@SportType) + ', @LeagueId =' + CONVERT(VARCHAR(10),@LeagueId)
		INSERT INTO dbo.SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END

END
GO