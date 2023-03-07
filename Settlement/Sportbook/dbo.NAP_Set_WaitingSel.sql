/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingSel] 
	@MatchCode 		NVARCHAR(50) = ''
	, @SportType 	SMALLINT = 0
	, @LeagueIds 	VARCHAR(MAX) = '0' -- 0 for ALL Leagues
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
		- 20201211@Louisa: remove unused code [Redmine:#146239]
		- 20210205@Louisa: Cricket AIO [Redmine:#148870]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20210917@Kathy: write log if SP run too long
		- 20210906@Louisa: Get configuration from table SettlementResultTableSetting [Redmine:#160478]
		- 20211118@Louisa: EventStatusReason for soccer only [Redmine:#164408]
		- 20211022@Kathy: Support Settlement Exclusion for Parlay Sub Tickets [Redmine:#163172]
		- 20211215@Kathy: Soccer - Include calculate parlay into calculate single tickets process [Redmine:#166072]
		- 20220620@Louisa: Extend Best Of Map Esports from M9 up to M30 [Redmine:#174252]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20221021@Louisa: Enhancement [Redmine:#180306]
		- 20230215@Aries: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]

	Param's explanation:  
		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @matchid INT, @StartTime DATETIME, @EndTime	DATETIME, @SqlCommand VARCHAR(MAX)
		,@MinBettype SMALLINT, @MaxBettype SMALLINT, @n	INT = 2147483647
		,@IsCentral BIT

	SET @StartTime = GETDATE()

	SELECT @MatchCode = ISNULL(@MatchCode, '')
			,@LeagueIds = ISNULL(@LeagueIDs, '0')
			,@SportType = ISNULL(@SportType, 0)

	IF ISNUMERIC(@MatchCode) = 1
		SET @matchid = CAST(@MatchCode AS INT)
	
	DECLARE @tmpLeagueID	 TABLE ( LeagueId INT )

	DECLARE @TempMatch TABLE (
		MatchId				INT
		,leagueid			INT
		,homeid				INT
		,awayid				INT
		,matchcode			NVARCHAR(100)
		,finalhomescore		INT
		,finalawayscore		INT
		,betstatus			NVARCHAR(100)
		,goalrecord			VARCHAR(50)
		,hthomescore		INT
		,htawayscore		INT
		,eventstatus		NVARCHAR(100)
		,IsNeutral			BIT
		,SettlementStatus	TINYINT
		,AutoSetting		TINYINT
		,ChildMatchType		TINYINT
		,SportType						SMALLINT
		,SingleStatus 					INT
		,ParlayStatus 					INT
		,IsSingle 						BIT
		,IsMixParlay 					BIT
		,IsExistFGLG 					BIT DEFAULT (0)
		,IsExistHTFGLG 					BIT DEFAULT (0)
		,IsExistFastMarket				BIT DEFAULT (0)
		,IsRunningFastMarket			BIT DEFAULT (0)
		,IsExistFastMarketResult		BIT DEFAULT (0)
		,IsExistEarlyBettypes 			BIT DEFAULT (0)
		,IsRunningEarlyBettypes			BIT DEFAULT (0)
		,IsWaitingEarlyBettypes			BIT DEFAULT (0)
		,IsExistMarkedTicket			BIT DEFAULT (0)
		,IsExistRunningTicket			BIT DEFAULT (0)
		,EventStatusReason				TINYINT
	)

	CREATE TABLE #tblBettype (bettype SMALLINT, GroupId SMALLINT, IsFGLG BIT, IsEarly BIT)
	
	CREATE TABLE #tblResultDetail (matchid INT, ResourceId VARCHAR(20), HomeValue VARCHAR(50), AwayValue VARCHAR(50), ResultStatusID TINYINT, SettlementStatusID TINYINT)
	
	CREATE INDEX IX_ResultDetail ON #tblResultDetail (matchid, ResourceId)
	
	CREATE TABLE #tblBetStatus (matchid INT, bettype SMALLINT, isRunning INT, IsWaiting INT, groupId TINYINT ,IsParlay BIT, IsFGLG BIT, IsEarly BIT)
	
	CREATE TABLE #temp_match_parlay (transid BIGINT, matchid INT, refno BIGINT)
	
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO @tmpLeagueID ( LeagueId )
	SELECT Value FROM string_split(@LeagueIDs, ',' )

	;WITH SingleTicket AS (
		SELECT matchid, sporttype, MIN(IsCalculating) AS IsCalculating
		FROM dbo.Single_Calculate_Queue s WITH(NOLOCK)
		WHERE (Starttime > DATEADD(MINUTE, -10, GETDATE()) 
				OR s.IsCalculating IN (0,1)
			) 
			AND s.sporttype = @sporttype
		GROUP BY matchid, SportType
	), ParlayTicket AS (
		SELECT p.matchid, m.sporttype
			,MIN(IsCalculating) AS IsCalculating
			,MAX(CASE WHEN IsCalculating = 1 THEN 1 ELSE 0 END) AS Running -- match have waitting, running, completed status
		FROM dbo.Parlay_Calculate_Queue p WITH(NOLOCK)
			INNER JOIN dbo.match m WITH (NOLOCK)
				ON p.matchid = m.matchid
		WHERE (p.Starttime > DATEADD(MINUTE, -10, GETDATE()) 
				OR p.IsCalculating IN (0,1) 
			) 
			AND p.sporttype = @sporttype
		GROUP BY p.matchid, m.sporttype
	)
	
	INSERT INTO @TempMatch(
		MatchId
		,leagueid			
		,homeid				
		,awayid				
		,matchcode			
		,finalhomescore		
		,finalawayscore		
		,betstatus			
		,goalrecord			
		,hthomescore		
		,htawayscore		
		,eventstatus		
		,IsNeutral			
		,SettlementStatus	
		,AutoSetting		
		,ChildMatchType
		,SportType
		,SingleStatus
		,ParlayStatus
		,IsSingle
		,IsMixParlay
		,EventStatusReason
	)
	SELECT m.MatchId
		,m.leagueid			
		,homeid				
		,awayid				
		,matchcode			
		,finalhomescore		
		,finalawayscore		
		,betstatus			
		,goalrecord			
		,hthomescore		
		,htawayscore		
		,eventstatus		
		,ISNULL(m.isNeutral, CONVERT(BIT, 0))		
		,ISNULL(m.SettlementStatus, 0)
		,ISNULL(m.AutoSetting, 0)	
		,ChildMatchType
		,q.SportType
		,SingleStatus
		,ParlayStatus
		,IsSingle
		,IsMixParlay
		,m.EventStatusReason
	FROM  (
		SELECT ISNULL(sg.matchid, pl.matchid) AS MatchId
			, ISNULL(sg.SportType, pl.sporttype) AS SportType
			, sg.IsCalculating AS SingleStatus
			, CASE WHEN pl.Running = 1 THEN pl.Running ELSE pl.IsCalculating END AS ParlayStatus
			, CAST(ISNULL(sg.IsCalculating, 0) AS BIT) AS IsSingle
			, CASE WHEN pl.Running = 1 THEN pl.Running ELSE CAST(ISNULL(pl.IsCalculating, 0) AS BIT) END AS IsMixParlay
		FROM SingleTicket sg
			FULL OUTER JOIN ParlayTicket pl ON sg.matchid = pl.matchid
	) q
		INNER JOIN dbo.Match m WITH(NOLOCK) ON	q.MatchId = m.matchid	
		INNER JOIN @tmpLeagueID tmp ON tmp.LeagueId = 0 OR tmp.LeagueId = m.LeagueID
	WHERE m.sporttype = @sporttype
		AND (@matchcode = '' OR (m.matchid = @matchid OR m.matchcode = @matchcode))
		AND 1 = CASE WHEN ISNULL(m.ChildMatchType,0) = 200 AND m.ParentID IS NOT NULL AND m.sporttype = 50 THEN 0 ELSE 1 END -- dont get the child match of cricket
	
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
		SELECT  m.matchId, b.bettype, b.isRunning, b.isWaiting, b.GroupId, 0, b.IsFGLG, b.IsEarly
		FROM	(
			SELECT TOP (@n) MatchId FROM @TempMatch
		) AS m
			CROSS APPLY
			(
				SELECT	b.bettype
					, MAX(CASE WHEN b.statusID = 0 THEN 1 ELSE 0 END) isRunning
					, MAX(CASE WHEN b.statusID = 1 THEN 1 ELSE 0 END) isWaiting	
					, MAX(t.GroupId) AS GroupId
					, MAX(CASE WHEN t.IsFGLG = 1 THEN 1 ELSE 0 END) AS IsFGLG
					, MAX(CASE WHEN t.IsEarly = 1 THEN 1 ELSE 0 END) AS IsEarly				
				FROM	dbo.bettrans b WITH (NOLOCK)
					INNER JOIN #tblBettype t
						ON b.bettype = t.bettype
				WHERE	b.matchid = m.MatchId
						AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
						AND b.statusID NOT BETWEEN 101 AND 102
						AND b.bettype BETWEEN @MinBettype AND @MaxBettype
				GROUP BY b.bettype
			)b
		OPTION (OPTIMIZE FOR (@n = 1))
		
		INSERT INTO #tblBetStatus (matchid, bettype, isRunning,IsWaiting, groupId, IsParlay,IsFGLG, IsEarly)
		SELECT  m.MatchId, bm.bettype, bm.isRunning, bm.IsWaiting, bm.GroupId, 1,bm.IsFGLG, bm.IsEarly
		FROM	(
			SELECT TOP (@n) MatchId FROM @TempMatch
		) AS m
			CROSS APPLY 
			(
				SELECT	bm.bettype
					, MAX(CASE WHEN bm.statusID = 0 THEN 1 ELSE 0 END) isRunning
					, MAX(CASE WHEN bm.statusID = 1 THEN 1 ELSE 0 END) IsWaiting
					, MAX(t.groupid) AS GroupId
					, MAX(CASE WHEN t.IsFGLG = 1 THEN 1 ELSE 0 END) AS IsFGLG
					, MAX(CASE WHEN t.IsEarly = 1 THEN 1 ELSE 0 END) AS IsEarly
				FROM	dbo.bettransm bm WITH (NOLOCK)
					INNER JOIN #tblBettype t
						ON	bm.bettype = t.bettype
				WHERE	bm.matchid = m.MatchId
						AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						AND bm.statusID NOT BETWEEN 101 AND 102
						AND bm.bettype BETWEEN @MinBettype AND @MaxBettype
				GROUP BY bm.bettype
			)bm
		OPTION (OPTIMIZE FOR (@n = 1))

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
				,MAX(CASE WHEN isRunning = 1 AND IsParlay = 0 THEN 1 ELSE 0 END ) AS IsExistRunningTicket
			FROM #tblBetStatus
			GROUP BY matchid
		)
		UPDATE t
		SET IsExistFGLG = CASE WHEN tt.IsExistFGLG > 0 THEN 1 ELSE 0 END
			,IsExistHTFGLG = CASE WHEN tt.IsExistHTFGLG > 0 THEN 1 ELSE 0 END
			,IsExistFastMarket = CASE WHEN tt.IsExistFastMarket > 0 THEN 1 ELSE 0 END
			,IsRunningFastMarket = CASE WHEN tt.IsRunningFastMarket > 0 THEN 1 ELSE 0 END
			,IsExistEarlyBettypes = CASE WHEN tt.IsExistEarlyBettypes > 0 OR tt.IsExistEarlyBettypesParlay > 0 THEN 1 ELSE 0 END
			,IsRunningEarlyBettypes = CASE WHEN tt.IsRunningEarlyBettypes > 0 OR tt.IsRunningEarlyBettypesParlay > 0 THEN 1 ELSE 0 END
			,IsWaitingEarlyBettypes = CASE WHEN tt.IsWaitingEarlyBettypes > 0 OR tt.IsWaitingEarlyBettypesParlay > 0 THEN 1 ELSE 0 END
			,IsExistRunningTicket = tt.IsExistRunningTicket
		FROM @TempMatch t
		INNER JOIN cteBetStatus tt ON t.MatchId = tt.matchid	
	END

	DECLARE @tmpMatchMarked TABLE (MatchId INT, IsExistMarkedTicket BIT DEFAULT(0))
	CREATE TABLE #tmpMarkedTransaction (transId BIGINT, matchId INT)

	INSERT INTO #tmpMarkedTransaction (transId, matchId)
	SELECT	mt.TransId, mt.matchid
	FROM	@TempMatch m
		CROSS APPLY (
			SELECT	mt.TransId, mt.MatchId
			FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
			WHERE	m.matchid = mt.MatchId
		)mt
	WHERE m.SportType <> 50

	INSERT INTO @tmpMatchMarked(MatchId)
	SELECT	DISTINCT matchId
	FROM	#tmpMarkedTransaction
	
	IF @@ROWCOUNT <> 0
	BEGIN
		UPDATE	mk 
			SET  IsExistMarkedTicket = m.HasMarkedSingle
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
								AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
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
		-- single
		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	@tmpMatchCompleted m
			CROSS APPLY (
				SELECT 1 AS IsExistRunningTicket
				FROM (
						SELECT	b.transid, tmp.MatchId
						FROM	dbo.bettrans b WITH(NOLOCK)
							INNER JOIN @TempMatch tmp 
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
				GROUP BY b.MatchId
			) t
		
		-- parlay
		INSERT INTO #temp_match_parlay (transid, matchid, refno)
		SELECT	0, tmp.MatchId, bm.refno
		FROM @tmpMatchCompleted m
			INNER JOIN dbo.bettransm bm WITH(NOLOCK) ON m.MatchId = bm.matchid
			INNER JOIN @TempMatch tmp	ON	bm.matchid = tmp.MatchId
		WHERE	bm.statusID = 0
			AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
			AND m.IsExistRunningTicket = 0								
		
		IF EXISTS (SELECT TOP 1 1 FROM #temp_match_parlay)
		BEGIN
			UPDATE   t
				SET transid = b.transid
			FROM   #temp_match_parlay  t
				INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON b.matchid = 29 AND b.bettype = 29 AND b.refno = t.Refno
			
			UPDATE	m 
				SET IsExistRunningTicket = CASE WHEN m.IsExistRunningTicket = 0 THEN t.IsExistRunningTicketParlay ELSE m.IsExistRunningTicket END
			FROM	@tmpMatchCompleted m
					CROSS APPLY (
								SELECT 1 AS IsExistRunningTicketParlay
								FROM (
										SELECT	transid, MatchId
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
									GROUP BY b.matchid
								) t
			--WHERE m.IsExistRunningTicket = 0
		END
				
		UPDATE m 
			SET IsExistRunningTicket = t.IsExistRunningTicket
		FROM	@TempMatch m
			INNER JOIN @tmpMatchCompleted t
				ON m.matchid = t.MatchId
	END
	
	SELECT m.matchid, m.leagueid, m.homeid, m.awayid, m.matchcode, m.finalhomescore, m.finalawayscore
		, m.betstatus, m.sporttype, m.goalrecord
		, m.hthomescore AS HalfTimeHomeScore
		, m.htawayscore AS HalfTimeAwayScore
		, ISNULL(mr.calculate, 0) AS IsCalculated
		, ISNULL(mr.multiple, 0) AS IsMultiCaled
		, ISNULL(mr.refund, 0) AS IsRefund
		, ISNULL(mr.calrefund, 0) AS IsCalRefund
		, m.eventstatus
		, m.IsNeutral
		, ISNULL(mr.IsHTCal, 0) AS IsHalfTimeCal
		, m.SettlementStatus
		, m.AutoSetting
		, m.IsExistFGLG
		, m.IsExistHTFGLG
		, m.SingleStatus AS IsCalculatingSingle
		, m.ParlayStatus AS IsCalculatingMP
		, m.IsExistFastMarket
		, m.IsExistFastMarketResult
		, m.IsRunningFastMarket
		, m.IsExistEarlyBettypes
		, m.ChildMatchType
		, m.IsRunningEarlyBettypes
		, m.IsWaitingEarlyBettypes
		,m.IsExistMarkedTicket
		,m.IsExistRunningTicket
		,ISNULL(ciHT.username,'') AS suspenderHalfTime 
		,ISNULL(ciFT.username,'') AS suspenderFullTime
		,m.EventStatusReason
		,mr.BestOfMap
	FROM @TempMatch m
		LEFT JOIN dbo.match_remark mr WITH(NOLOCK) ON m.matchid = mr.matchid
		LEFT JOIN CustDB.dbo.custInfo ciHT WITH(NOLOCK) ON ciHT.custid = mr.ConfirmHT
		LEFT JOIN CustDB.dbo.custInfo ciFT WITH(NOLOCK) ON ciFT.custid = mr.ConfirmFT

	SET @EndTime = GETDATE()
	IF DATEDIFF(MILLISECOND, @StartTime, @EndTime) > 5000
	BEGIN
		SET @SqlCommand = 'EXEC NAP_Set_WaitingSel @MatchCode =''' + ISNULL(@MatchCode,'') + ''', @SportType = ' + CONVERT(VARCHAR(10),@SportType) + ', @LeagueIds =' + @LeagueIds
		INSERT INTO dbo.SettlementRunSPLog(LogDate, SqlCommand, StartTime, EndTime)
		SELECT GETDATE(), @SqlCommand, @StartTime, @EndTime
	END

END
GO