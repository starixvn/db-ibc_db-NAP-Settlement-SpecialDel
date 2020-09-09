/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[NAP_Set_WaitingSel] 
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
		- 20190620@Kathy: PH AIO Phase 4 [Redmine:#109584]
		- 20191112@Sol: Incorporate PHAIO 5 [Redmine:#121681]
		- 20200212@Sol: Show all bet option for Early of Esport based on OddsES table - [#128069]
		- 20200227@Sol: Show Result of SBO on Main Calculate & Main Popup for Soccer - [Redmine:#129780]
		- 20200515@Kathy: Settlement Exclusion for Parlay [Redmine:#134103]
		- 20200619@Kathy: Duplicate transid on table MarkedTransaction [Redmine:#136146]
		- 20200827@Louisa: Get external score [Redmine:#139979]
	
	Param's explanation:  
		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @matchid INT, @StartTime DATETIME, @EndTime	DATETIME, @SqlCommand VARCHAR(MAX)
		,@MinBettype SMALLINT, @MaxBettype SMALLINT,@isSettingByProfile BIT = 0
		
	SELECT @MatchCode = ISNULL(@MatchCode, ''), @LeagueId = ISNULL(@LeagueID, 0), @SportType = ISNULL(@SportType, 0)

	IF ISNUMERIC(@MatchCode) = 1
		SET @matchid = CAST(@MatchCode AS INT)
	
	DECLARE @TempMatch TABLE (
		MatchId							INT
		,SportType						SMALLINT
		,SingleStatus 					INT
		,ParlayStatus 					INT
		,IsSingle 						BIT
		,IsMixParlay 					BIT
		,IsExistFGLG 					BIT
		,IsExistHTFGLG 					BIT
		,IsExistFastMarket				BIT
		,IsRunningFastMarket			BIT
		,IsExistFastMarketResult		BIT
		,IsExistEarlyBettypes 			BIT
		,IsExistEarlyBettypesParlay 	BIT
		,IsRunningEarlyBettypes			BIT
		,IsRunningEarlyBettypesParlay	BIT
		,IsWaitingEarlyBettypes			BIT
		,IsWaitingEarlyBettypesParlay	BIT
		,IsExistMarkedTicket			BIT
		,IsExistRunningTicket			BIT
		,IsExistMarkedTicketParlay		BIT
	)
	DECLARE @tmp_ESportMatch TABLE (matchid INT)
	DECLARE @tmp_ExternalSourceResult TABLE (Matchid INT, SourceId TINYINT, ExHTHomeScore INT, ExHTAwayScore INT, ExFTHomeScore INT, ExFTAwayScore INT)

	CREATE TABLE #tblBettype (bettype SMALLINT, GroupId SMALLINT, IsFGLG BIT, IsEarly BIT)
	
	CREATE TABLE #tblResultDetail (matchid INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultStatusID TINYINT, SettlementStatusID TINYINT)
	
	CREATE INDEX IX_ResultDetail ON #tblResultDetail (matchid, ResourceId)
	
	CREATE TABLE #tblBetStatus (matchid INT, bettype SMALLINT, isRunning INT, IsWaiting INT, groupId TINYINT ,IsParlay BIT, IsFGLG BIT, IsEarly BIT)
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_Set_SettingByProfile(@sporttype))
	BEGIN
		SELECT @isSettingByProfile = 1
	END
	
	;WITH SingleTicket AS (
		SELECT matchid, sporttype, MIN(IsCalculating) AS IsCalculating
		FROM dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
			AND (sporttype = @sporttype OR @sporttype = 0)
			AND (leagueid = @leagueid OR @leagueId = 0)
		GROUP BY matchid, SportType
	), ParlayTicket AS (
		SELECT p.matchid, m.sporttype, MIN(IsCalculating) AS IsCalculating
		FROM dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK)
				ON p.matchid = m.matchid
		WHERE Starttime > DATEADD(MINUTE, -10, GETDATE())
			AND (m.sporttype = @sporttype OR @sporttype = 0)
			AND (m.leagueid = @leagueid OR @leagueId = 0)
		GROUP BY p.matchid, m.sporttype
	)
	
	INSERT INTO @TempMatch(MatchId, SportType, SingleStatus, ParlayStatus, IsSingle, IsMixParlay, IsExistFGLG, IsExistHTFGLG
		, IsExistFastMarket, IsRunningFastMarket, IsExistFastMarketResult
		, IsExistEarlyBettypes, IsExistEarlyBettypesParlay, IsRunningEarlyBettypes, IsRunningEarlyBettypesParlay, IsWaitingEarlyBettypes, IsWaitingEarlyBettypesParlay
		, IsExistMarkedTicket, IsExistRunningTicket, IsExistMarkedTicketParlay
	)
	SELECT ISNULL(sg.matchid, pl.matchid) AS MatchId
		, ISNULL(sg.SportType, pl.sporttype) AS SportType
		, sg.IsCalculating AS SingleStatus
		, pl.IsCalculating AS ParlayStatus
		, CAST(ISNULL(sg.IsCalculating, 0) AS BIT) AS IsSingle
		, CAST(ISNULL(pl.IsCalculating, 0) AS BIT) AS IsMixParlay
		, CONVERT(BIT, 0) AS IsExistFGLG
		, CONVERT(BIT, 0) AS IsExistHTFGLG
		, 0 AS IsExistFastMarket
		, 0 AS IsRunningFastMarket
		, 0 AS IsExistFastMarketResult
		, 0 AS IsExistEarlyBettypes
		, 0 AS IsExistEarlyBettypesParlay
		, 0 AS IsRunningEarlyBettypes
		, 0 AS IsRunningEarlyBettypesParlay
		, 0 AS IsWaitingEarlyBettypes
		, 0 AS IsWaitingEarlyBettypesParlay
		, 0 AS IsExistMarkedTicket
		, 0 AS IsExistRunningTicket
		, 0 AS IsExistMarkedTicketParlay
	FROM SingleTicket sg
		FULL OUTER JOIN ParlayTicket pl ON sg.matchid = pl.matchid
	
	IF @@ROWCOUNT > 0
	BEGIN
		INSERT INTO #tblBettype (bettype, GroupId, IsFGLG, IsEarly)
		SELECT	BetType, f.GroupId, f.IsFGLG, ISNULL(e.IsEarly, 0)
		FROM	dbo.f_Set_GetGroupBettypes() f
			OUTER APPLY (
				SELECT 1 AS IsEarly
				FROM dbo.f_Set_GetEarlyBettypes() e
				WHERE f.BetType = e.bettype
			) e
		WHERE	f.IsUsedGoalRecordValue = 1 
				OR f.GroupId = 9 
				OR e.IsEarly = 1

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
					SET IsExistFastMarketResult = 1
				FROM	@TempMatch m
					INNER JOIN (
						SELECT	r.matchid
						FROM #tblResultDetail r
							INNER JOIN #tblBettype bt
								ON r.ResourceId LIKE CAST(BetType AS VARCHAR(20)) + '__'
						WHERE bt.GroupId = 9
						GROUP BY r.matchid
					) rs
						ON m.MatchId = rs.matchId
		END
		
		INSERT INTO #tblBetStatus (matchid, bettype, isRunning,IsWaiting, groupId, IsParlay, IsFGLG, IsEarly)
		SELECT  b.matchid, b.bettype, MAX(isRunning),MAX(isWaiting), bt.GroupId, 0, bt.IsFGLG, bt.IsEarly
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
		GROUP BY b.matchid, b.bettype, bt.GroupId,bt.IsFGLG, bt.IsEarly
		
		INSERT INTO #tblBetStatus (matchid, bettype, isRunning,IsWaiting, groupId, IsParlay,IsFGLG, IsEarly)
		SELECT  bm.matchid, bm.bettype, MAX(bm.isRunning),MAX(bm.IsWaiting), bt.GroupId, 1,bt.IsFGLG, bt.IsEarly
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
		GROUP BY bm.matchid, bm.bettype, bt.GroupId,bt.IsFGLG, bt.IsEarly

		;WITH cteBetStatus
		AS(
			SELECT matchid
				,MAX(CASE WHEN groupId IN (1,3) AND IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistHTFGLG
				,MAX(CASE WHEN groupId IN (2,4) AND IsFGLG = 1 THEN 1 ELSE 0 END) AS IsExistFGLG
				,MAX(CASE WHEN groupId = 9 AND IsParlay = 0 THEN 1 ELSE 0 END) AS IsExistFastMarket
				,MAX(CASE WHEN groupId = 9 AND IsParlay = 0 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningFastMarket
				,MAX(CASE WHEN IsEarly = 1 AND IsParlay = 0 THEN 1 ELSE 0 END) AS IsExistEarlyBettypes
				,MAX(CASE WHEN IsEarly = 1 AND IsParlay = 1 THEN 1 ELSE 0 END) AS IsExistEarlyBettypesParlay
				,MAX(CASE WHEN IsEarly = 1 AND IsParlay = 0 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypes
				,MAX(CASE WHEN IsEarly = 1 AND IsParlay = 1 AND isRunning > 0 THEN 1 ELSE 0 END) AS IsRunningEarlyBettypesParlay
				,MAX(CASE WHEN IsEarly = 1 AND IsParlay = 0 AND isWaiting > 0 THEN 1 ELSE 0 END) AS IsWaitingEarlyBettypes
				,MAX(CASE WHEN IsEarly = 1 AND IsParlay = 1 AND isWaiting > 0 THEN 1 ELSE 0 END) AS IsWaitingEarlyBettypesParlay
			FROM #tblBetStatus
			GROUP BY matchid
		)
		UPDATE t
		SET IsExistFGLG = CASE WHEN tt.IsExistFGLG > 0 THEN 1 ELSE 0 END
			,IsExistHTFGLG = CASE WHEN tt.IsExistHTFGLG > 0 THEN 1 ELSE 0 END
			,IsExistFastMarket = CASE WHEN tt.IsExistFastMarket > 0 THEN 1 ELSE 0 END
			,IsRunningFastMarket = CASE WHEN tt.IsRunningFastMarket > 0 THEN 1 ELSE 0 END
			,IsExistEarlyBettypes = CASE WHEN tt.IsExistEarlyBettypes > 0 THEN 1 ELSE 0 END
			,IsExistEarlyBettypesParlay = CASE WHEN tt.IsExistEarlyBettypesParlay > 0 THEN 1 ELSE 0 END
			,IsRunningEarlyBettypes = CASE WHEN tt.IsRunningEarlyBettypes > 0 THEN 1 ELSE 0 END
			,IsRunningEarlyBettypesParlay = CASE WHEN tt.IsRunningEarlyBettypesParlay > 0 THEN 1 ELSE 0 END
			,IsWaitingEarlyBettypes = CASE WHEN tt.IsWaitingEarlyBettypes > 0 THEN 1 ELSE 0 END
			,IsWaitingEarlyBettypesParlay = CASE WHEN tt.IsWaitingEarlyBettypesParlay >  0 THEN 1 ELSE 0 END
		FROM @TempMatch t
		INNER JOIN cteBetStatus tt ON t.MatchId = tt.MatchId	
	END

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0), IsExistMarkedTicketParlay BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)

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
	
	IF (@SportType = 43)
	BEGIN

		INSERT INTO @tmp_ESportMatch(MatchId)
		SELECT DISTINCT m.MatchId
		FROM DBPRO.BODB02.dbo.oddsES o WITH (NOLOCK)
				INNER JOIN f_Set_GetEarlyBettypes() f
					ON o.bettype = f.bettype
				INNER JOIN @TempMatch m
					ON m.matchid = o.matchid 
		WHERE m.sporttype = 43

	END

	-- get score from external source and return to web for result comparing
	DECLARE @queryMatch NVARCHAR(MAX) = '', @MatchIds VARCHAR(MAX) = ''
	DECLARE @execSql NVARCHAR(MAX) = ''

	SELECT @MatchIds = COALESCE(@MatchIds + ',' + CAST(MatchId AS VARCHAR(20)),CAST(MatchId AS VARCHAR(20)))
	FROM @TempMatch

	SET @queryMatch = '	
						SELECT 
							matchid, SourceId 
							, MAX(CASE WHEN TypeId = 1 THEN HomeValue END) AS HTHomeScore
							, MAX(CASE WHEN TypeId = 1 THEN AwayValue END) AS HTAwayScore
							, MAX(CASE WHEN TypeId = 2 THEN HomeValue END) AS FTHomeScore
							, MAX(CASE WHEN TypeId = 2 THEN AwayValue END) AS FTAwayScore
						FROM 
						(
							SELECT 
								rd.matchid, SourceId, TypeId, HomeValue, AwayValue, CreatedDate
								, RANK()OVER(PARTITION BY rd.matchid, SourceId, TypeId ORDER BY createddate DESC) maxDate
							FROM bodb02.dbo.ProviderResultDetail rd WITH(NOLOCK)
								INNER JOIN (SELECT val FROM BODB02.dbo.f_SplitString(@matchids , '','')) tm
														ON rd.matchid = tm.val
							WHERE TypeId IN (1,2) AND SourceId = 1
						) t
						WHERE maxDate = 1
						GROUP BY t.MatchId, SourceId
						OPTION (MAXRECURSION 0)
					'
	SET @execSql = 'DBPRO.bodb02.dbo.sp_executesql @queryMatch, N''@MatchIds VARCHAR(MAX)'', @matchids'

	INSERT INTO @tmp_ExternalSourceResult(Matchid, SourceId, ExHTHomeScore, ExHTAwayScore, ExFTHomeScore, ExFTAwayScore)
	EXECUTE	sys.sp_executesql @execSql, N'@queryMatch NVARCHAR(MAX), @MatchIds VARCHAR(MAX)', @queryMatch, @matchids

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
		, CASE
			WHEN tm.IsExistFastMarket = 0 AND tm.IsExistFastMarketResult = 0 THEN 'N/A'
			WHEN tm.IsExistFastMarket = 0 AND tm.IsExistFastMarketResult = 1 THEN 'No Ticket'
			WHEN tm.IsRunningFastMarket > 0 THEN 'Running'
			ELSE 'Completed'
		END AS AutoSettleFastMarket
		, CASE
			WHEN tm.IsExistEarlyBettypes = 0 AND tm.IsExistEarlyBettypesParlay = 0 AND (m.ChildMatchType IN (202) OR te.matchid IS NOT NULL)THEN 'No Ticket'
			WHEN tm.IsExistEarlyBettypes = 0 AND tm.IsExistEarlyBettypesParlay = 0 THEN 'N/A'
			WHEN tm.IsRunningEarlyBettypes > 0 THEN 'Running'
			WHEN tm.IsWaitingEarlyBettypes > 0 THEN 'Waiting'
			WHEN tm.IsExistEarlyBettypes = 0 AND tm.IsRunningEarlyBettypesParlay > 0 THEN 'Parlay Running'
			WHEN tm.IsExistEarlyBettypes = 0 AND tm.IsWaitingEarlyBettypesParlay > 0 THEN 'Parlay Waiting'
			ELSE 'Completed'
		END AS EarlySettleStatus
		,tm.IsExistMarkedTicket
		,tm.IsExistRunningTicket
		,tm.IsExistMarkedTicketParlay
		--,exSource.SourceId
		--,exSource.ExHTHomeScore
		--,exSource.ExHTAwayScore
		--,exSource.ExFTHomeScore
		--,exSource.ExFTAwayScore
		,ISNULL(ciHT.username,'') AS suspenderHalfTime 
		,ISNULL(ciFT.username,'') AS suspenderFullTime
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN @TempMatch tm ON m.matchid = tm.matchid
		LEFT JOIN @tmp_ExternalSourceResult exSource ON tm.matchid = exSource.Matchid
		LEFT JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		LEFT JOIN @tmp_ESportMatch te ON te.matchid = m.matchid
		LEFT JOIN CustDB.dbo.custInfo ciHT WITH(NOLOCK) ON ciHT.custid = mr.ConfirmHT
		LEFT JOIN CustDB.dbo.custInfo ciFT WITH(NOLOCK) ON ciFT.custid = mr.ConfirmFT
	WHERE m.sporttype = @sporttype
		AND (@LeagueId = 0 OR m.leagueid = @LeagueId)
		AND (@matchcode = '' OR (m.matchid = @matchid OR m.matchcode = @matchcode))
		

	DECLARE @matchidList VARCHAR(MAX) = ''
	    
	SELECT @matchidList =  @matchidList + ',' + CAST(matchid AS VARCHAR(20))
	FROM @TempMatch
	SET @matchidList = SUBSTRING(@matchidList, 2, LEN(@matchidList))
	    
	EXEC DBPRO.bodb02.dbo.NAP_Set_ResultDetailSel
		@matchidList = @matchidList


	SET @EndTime = GETDATE()
	IF DATEDIFF(MILLISECOND, @StartTime, @EndTime) > 1000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_WaitingSel @MatchCode =''' + ISNULL(@MatchCode,'') + ''', @SportType = ' + CONVERT(VARCHAR(10),@SportType) + ', @LeagueId =' + CONVERT(VARCHAR(10),@LeagueId)
		INSERT INTO dbo.SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END

END
GO