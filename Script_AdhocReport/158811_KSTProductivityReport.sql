/*
	Created by: 20210723@Louisa
	Task: Keyscore Productivity Report [Redmine:#158811]
	Server: db061
	DB: dbacc/bodb02

	Revision:
		20211026@Louisa: Modify for Auto Settle Cricket + get configuration from SettlementResultTableSetting
		20231219@Louisa: Exclude RedCat88 [Redmine:#198365]
		2021-04-08: Move Cricket to ResultDetailOS
		2021-05-31: Release Soccer PinGoal
		2021-07-19: Move Beach Volleyball to ResultDetailOS
		2021-08-18: Release Auto settle Virtual Cricket
		2021-10-07: Move Volleyball to ResultDetailOS
		2022-02-17: release Pingoal basketball
		2022-12-19: release Pingoal ESports
		2023-04-12: release Table Tennis - move auto from AutoPayoutResultDetail to AutoPayoutResultDetailOS
		2024-01-12: Separate 2 column AutoCal and AutoRefund from column AutoSettle
		2024-08-05: release Table Tennis - move settle form table match to AutoPayoutResultDetail, add Auto Payout Kabaddi
		20240905@Kathy: - fix bug table tennis, kabaddi
						- correct the way to get @movebet, @BU of system [Redmine:#210398]
						
		- 20241008@Kathy: exclude main match interval resource of table tennis [Redmine:#211924]
		- 20250612@Louisa: get sport applied auto payout dynamic [Redmine:#]
*/


USE bodb02
GO

/*
	*** Note: Whenever Sporttype transforms settle result from dbo.match to dbo.resultDetailXX, need to update block code "Other sports..."

	 *** Scope: SportBook
	 *** Exclude: hedge match, child match of Cricket Test Match, test match
	 *** Exclude : result of FastMarkets, Time Machine, Goal Record, Pingoal
*/


	DECLARE @fromDate DATETIME = '2025-06-01'
			,@toDate  DATETIME = '2025-06-30 23:59:59'
			
			,@MovebetDate SMALLDATETIME
			,@BUDate SMALLDATETIME

	SELECT @MovebetDate = CONVERT(SMALLDATETIME, VValue)
    FROM dbo.SystemSettings
    WHERE VName = 'MovebetDate'

	-- BU
	SELECT @BUDate = CONVERT(SMALLDATETIME, VValue)
    FROM dbo.MBUSettings with(nolock)
	where VName like 'BalanceUpDate'

	-------------------------------------------

	IF OBJECT_ID ('tempdb..#TempMatchInfo' ) IS NOT NULL	DROP TABLE #TempMatchInfo
	IF OBJECT_ID ('tempdb..#TempResultDetail') IS NOT NULL	DROP TABLE #TempResultDetail
	IF OBJECT_ID ('tempdb..#MatchId' ) IS NOT NULL			DROP TABLE #MatchId
	IF OBJECT_ID ('tempdb..#MatchIdAuto' ) IS NOT NULL		DROP TABLE #MatchIdAuto
	IF OBJECT_ID ('tempdb..#ResultTableSetting' ) IS NOT NULL		DROP TABLE #ResultTableSetting
	IF OBJECT_ID ('tempdb..#ResultTableSetting' ) IS NOT NULL		DROP TABLE #tmpResourceTableTennis
	IF OBJECT_ID ('tempdb..#tmpResourceTableTennis' ) IS NOT NULL		DROP TABLE #tmpResourceTableTennis

	CREATE TABLE #TempMatchInfo (
		matchid INT, eventdate VARCHAR(10), sporttype TINYINT, SportName NVARCHAR(100)
		 ,HomeName NVARCHAR(200), AwayName  NVARCHAR(200)
		 ,leagueid INT, leaguename  NVARCHAR(1000), LeagueGroupID SMALLINT, LeagueGroupName NVARCHAR(400), betstatus NVARCHAR(100), [range] tinyint, ParentId INT, ChildMatchType TINYINT
		)

	CREATE TABLE #MatchId (matchid INT, sporttype TINYINT, ResultTable TINYINT, eventdate VARCHAR(10),  betstatus NVARCHAR(100), [range] tinyint, ParentId INT, ChildMatchType TINYINT, HasAuto BIT)
	CREATE TABLE #TempResultDetail ( MatchId INT, ManualCalculated INT , ManualRefunded INT, AutoCal INT, AutoRefund INT )
	CREATE TABLE #ResultTableSetting ( sporttype SMALLINT, ResultTable TINYINT, HasAuto BIT  )
	CREATE TABLE #MatchIdAuto (matchid INT )
	CREATE TABLE #tmpResourceTableTennis (MatchId INT, ResourceId VARCHAR(20), SettlementStatusId TINYINT, LastModifyBy INT, ParentId INT, ChildMatchType TINYINT)

------------------------------------------------------------------------------------------------------------------
	INSERT INTO #ResultTableSetting ( sporttype, ResultTable, HasAuto)
	SELECT r.sporttype, r.ResultTable, CASE WHEN ISNULL(r.AP_Group,0) between 1 and 999 OR r.sporttype in (18,47,7) THEN 1 ELSE 0 END
	FROM DBPRO.bodb02.dbo.SettlementResultTableSetting r WITH(NOLOCK)

	-- match
	IF @toDate > @MovebetDate
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, HomeName, AwayName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus, [range], ParentId, ChildMatchType )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,home.teamname AS HomeName, away.teamname AS AwayName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
				,1 -- match
				,m.ParentID
				,m.ChildMatchType
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND m.eventdate > @MovebetDate and m.eventdate <= @toDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%'  
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID IN (113,252) THEN 0 --exclude PinGoal
						WHEN m.sporttype = 2 AND lg.GroupID = 122 AND m.eventdate >= '2022-02-17' THEN 0 --exclude PinGoal
						WHEN m.sporttype = 43 AND lg.GroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99
	END
	
	--match14
	IF @fromDate <= @MovebetDate 
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, HomeName, AwayName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus, [range], ParentId, ChildMatchType )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,home.teamname AS HomeName, away.teamname AS AwayName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
				,2 -- match14
				,m.ParentID
				,m.ChildMatchType
		FROM dbo.match14 m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND m.eventdate >= @BUDate AND m.eventdate <= @MovebetDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%' 
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID IN (113,252) THEN 0 --exclude PinGoal
						WHEN m.sporttype = 2 AND lg.GroupID = 122 AND m.eventdate >= '2022-02-17' THEN 0 --exclude PinGoal
						WHEN m.sporttype = 43 AND lg.GroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99
	END

	--match_bk
	IF @fromDate < @BUDate
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, HomeName, AwayName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus, [range], ParentId, ChildMatchType )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,home.teamname AS HomeName, away.teamname AS AwayName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
				,3 -- match_bk
				,m.ParentID
				,m.ChildMatchType
		FROM bodb_archive.dbo.match_bk m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND m.eventdate < @BUDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%' 
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID IN ( 113,252) THEN 0 --exclude PinGoal
						 WHEN m.sporttype = 2 AND lg.GroupID = 122 AND m.eventdate >= '2022-02-17' THEN 0 --exclude PinGoal
						 WHEN m.sporttype = 43 AND lg.GroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99

	END

	INSERT INTO #MatchId (matchid, sporttype, ResultTable, eventdate, betstatus, [range], ParentId, ChildMatchType, HasAuto)
	SELECT DISTINCT m.matchid, m.sporttype, ISNULL(ss.ResultTable,0), m.eventdate, m.betstatus, m.[range], m.ParentId, m.ChildMatchType, ss.HasAuto
	FROM #TempMatchInfo m
		LEFT JOIN #ResultTableSetting ss ON m.sporttype = ss.sporttype

	--Result
	IF EXISTS (SELECT 1 FROM #MatchId WHERE [range] = 1)
	BEGIN
		--ResultDetail
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN dbo.ResultDetail r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable  = 1
			AND m.[range] = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
			AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0  --Goal result
													ELSE 1 END
							ELSE 1 END 
		GROUP BY r.MatchId
	
		--ResultDetailOS
		INSERT INTO #tmpResourceTableTennis (MatchId, ResourceId, SettlementStatusId, LastModifyBy, ParentId, ChildMatchType)
		SELECT	r.MatchId
				,r.ResourceID
				,r.SettlementStatusID
				,r.LastModifyBy
				,m.ParentId 
				,m.ChildMatchType
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.sporttype = 18 
			AND m.eventdate >= '2024-08-01'
			
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND 1 = CASE 
						WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 0  -- 2021-04-08: Move Cricket to ResultDetailOS
						WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 0  -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
						WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 0 --2021-10-07: Move Volleyball to ResultDetailOS
						WHEN m.sporttype = 18 THEN 0
						ELSE 1	END
		GROUP BY r.MatchId

		--ResultDetailES
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailES r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 3
			AND m.[range] = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
		GROUP BY r.MatchId
	END
	
	--Result14
	IF EXISTS (SELECT 1 FROM #MatchId WHERE [range] = 2)
	BEGIN
		--ResultDetail14
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN dbo.ResultDetail14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable  = 1
			AND m.[range] = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
			AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0  --Goal result
													ELSE 1 END
							ELSE 1 END
		GROUP BY r.MatchId

		--ResultDetailOS14
		INSERT INTO #tmpResourceTableTennis (MatchId, ResourceId, SettlementStatusId, LastModifyBy, ParentId, ChildMatchType)
		SELECT	r.MatchId
				,r.ResourceID
				,r.SettlementStatusID
				,r.LastModifyBy
				,m.ParentId 
				,m.ChildMatchType
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.sporttype = 18 
			AND m.eventdate >= '2024-08-01'

		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND 1 = CASE WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 0  -- 2021-04-08: Move Cricket to ResultDetailOS
						WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 0  -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
						WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 0 --2021-10-07: Move Volleyball to ResultDetailOS
						when m.sporttype = 18 then 0
						ELSE 1	END
		GROUP BY r.MatchId

		--ResultDetailES14
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal , AutoRefund)
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailES14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 3
			AND m.[range] = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
		GROUP BY r.MatchId
	END

	--ResultBK
	IF EXISTS (SELECT 1 FROM #MatchId WHERE [range] = 3)
	BEGIN
		
		--ResultDetail_bk
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal , AutoRefund)
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN bodb_archive.dbo.ResultDetail_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable  = 1
			AND m.[range] = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
			AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0 --Goal result
													ELSE 1 END
							ELSE 1 END 
		GROUP BY r.MatchId

		--ResultDetailOS_bk
		INSERT INTO #tmpResourceTableTennis (MatchId, ResourceId, SettlementStatusId, LastModifyBy, ParentId, ChildMatchType)
		SELECT	r.MatchId
				,r.ResourceID
				,r.SettlementStatusID
				,r.LastModifyBy
				,m.ParentId 
				,m.ChildMatchType
		FROM #MatchId m 
			INNER JOIN  bodb_archive.dbo.ResultDetailOS_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.sporttype = 18 
			AND m.eventdate >= '2024-08-01'

		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund)
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  bodb_archive.dbo.ResultDetailOS_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND 1 = CASE WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 0  -- 2021-04-08: Move Cricket to ResultDetailOS
						WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 0  -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
						WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 0 --2021-10-07: Move Volleyball to ResultDetailOS
						when m.sporttype = 18 then 0
						ELSE 1	END
		GROUP BY r.MatchId

		--ResultDetailES_bk
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  bodb_archive.dbo.ResultDetailES_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 3
			AND m.[range] = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
		GROUP BY r.MatchId
	END

	--For table tennis
	BEGIN
		DELETE main 
		FROM	#tmpResourceTableTennis main
		WHERE	main.ParentId IS NULL 
				AND EXISTS (SELECT TOP 1 1 
							FROM	#tmpResourceTableTennis child
							WHERE	child.ParentId = main.MatchId
									AND 1 = CASE
												WHEN child.ChildMatchType = 12 AND main.ResourceId = '0101' THEN 1 -- SET 1
												WHEN child.ChildMatchType = 14 AND main.ResourceId = '0102' THEN 1 -- SET 2
												WHEN child.ChildMatchType = 15 AND main.ResourceId = '0103' THEN 1 -- SET 3
												WHEN child.ChildMatchType = 16 AND main.ResourceId = '0104' THEN 1 -- SET 4
												WHEN child.ChildMatchType = 17 AND main.ResourceId = '0105' THEN 1 -- SET 5
												WHEN child.ChildMatchType = 18 AND main.ResourceId = '0106' THEN 1 -- SET 6
												WHEN child.ChildMatchType = 19 AND main.ResourceId = '0107' THEN 1 -- SET 7
												ELSE 0
											END
				)

		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund)
		SELECT	MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCal
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #tmpResourceTableTennis 
		GROUP BY MatchId
	END
			
	------------------------ Auto Kabaddi, table tennis-------------------------------
	DECLARE @tmpAuto TABLE (MatchId INT)
	
	INSERT INTO @tmpAuto(MatchId)
	SELECT DISTINCT  m.MatchId
	FROM DBLOG.bodb_customerlog_Archive.dbo.SettlementPerformanceLog p with(nolock)
	INNER JOIN #MatchId m ON p.MatchId = m.matchid
	WHERE (m.HasAuto = 1 AND m.ResultTable = 0 OR (p.sporttype = 18 AND p.starttime <'2024-08-01'))
		AND p.IsAuto = 1
	
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
	SELECT	m.MatchId
		, CASE 
				WHEN ka.matchid IS NOT NULL THEN 0 
				WHEN m.betstatus = 'Refund;' THEN 0 
				ELSE 1 END	AS ManualCal
		, CASE 
				WHEN ka.matchid IS NOT NULL THEN 0 
				WHEN  m.betstatus = 'Refund;' THEN 1 
				ELSE 0 END	AS ManualRefund
		, CASE WHEN ka.matchid IS NOT NULL THEN 1 ELSE 0 END AS AutoCal
		, 0 AS AutoRefund
	FROM #MatchId m
		LEFT JOIN @tmpAuto ka 
			ON m.matchid  = ka.matchid
    WHERE m.HasAuto = 1 AND m.ResultTable = 0 

	------------------------ Other sports: Result is saved in dbo.match -------
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoCal, AutoRefund )
	SELECT	m.MatchId
		, CASE WHEN  m.betstatus = 'Refund;' THEN 0 ELSE 1 END	AS ManualCal
		, CASE WHEN  m.betstatus = 'Refund;' THEN 1 ELSE 0 END	AS ManualRefund
		, 0 AS AutoCal
		, 0 AS AutoRefund
	FROM #MatchId m
	WHERE 1 = CASE WHEN m.ResultTable = 0 AND m.HasAuto = 0  THEN 1
					WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 1 -- 2021-04-08: Move Cricket to ResultDetailOS
					WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 1 -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
					WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 1 --2021-10-07: Move Volleyball to ResultDetailOS
					WHEN m.sporttype = 8 AND m.eventdate < '2024-09-05' THEN 1
				ELSE 0 END
	--AND NOT EXISTS (SELECT top 1 1 from #TempResultDetail t where t.matchid = m.matchid)
	
	SELECT m.eventdate,   m.sportName 
		,case
			when m.LeagueGroupID = 42 THEN 'Virtual'
			when m.LeagueGroupID IN (74, 108, 113, 252) and m.sporttype = 1 then 'Virtual'
			when m.LeagueGroupID in (122) and m.sporttype = 2 then 'Virtual'
			when m.LeagueGroupID in (151) and m.sporttype = 43 then 'Virtual'
			else 'Real'
		end as 'Real/Virtual'
		,  m.LeagueGroupName
		, COUNT(DISTINCT r.matchid) AS Matches
		 ,SUM(r.ManualCalculated ) AS ManualCalculated
		 ,SUM(r.ManualRefunded ) AS ManualRefunded
		 ,SUM(r.AutoCal) AS AutoCal
		 ,SUM(r.AutoRefund) AS AutoRefund
		 ,SUM( ManualCalculated + ManualRefunded + AutoCal + AutoRefund) AS TotalSettledResourceId
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m ON r.MatchId = m.matchid
	GROUP BY m.eventdate,   m.sportName ,  m.LeagueGroupName 
		,case
			when m.LeagueGroupID = 42 THEN 'Virtual'
			when m.LeagueGroupID IN (74, 108, 113, 252) and m.sporttype = 1 then 'Virtual'
			when m.LeagueGroupID in (122) and m.sporttype = 2 then 'Virtual'
			when m.LeagueGroupID in (151) and m.sporttype = 43 then 'Virtual'
			else 'Real'
		end
	ORDER BY eventdate,  m.sportName ,  m.LeagueGroupName
		
	--Match vs Result	
	SELECT  YEAR(m.eventdate) AS Y
			,MONTH(m.eventdate) AS M	
			,SUM( ManualCalculated + ManualRefunded + AutoCal + AutoRefund) AS TotalSettledResourceId 
			,COUNT(DISTINCT r.matchid)	AS [Match] 
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m ON r.MatchId = m.matchid
	GROUP BY YEAR(m.eventdate), MONTH(m.eventdate)
	ORDER BY YEAR(m.eventdate), MONTH(m.eventdate)

	--Match vs Manual cal and Refund
	SELECT   YEAR(m.eventdate) AS Y
			,MONTH(m.eventdate) AS M	
			,SUM( ManualCalculated) ManualCalculated 
			,SUM(ManualRefunded) AS ManualRefunded 
			,COUNT(DISTINCT r.matchid)	AS Match 
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m ON r.MatchId = m.matchid
	GROUP BY YEAR(m.eventdate), MONTH(m.eventdate)
	ORDER BY YEAR(m.eventdate), MONTH(m.eventdate)

	--Manual vs Auto
	SELECT  YEAR(m.eventdate) AS Y
		,MONTH(m.eventdate) AS M	
		,SUM( ManualCalculated + ManualRefunded) AS [ManualSettled]
		,SUM( AutoCal) AS AutoCal
		,SUM( AutoRefund) AS AutoRefund
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m ON r.MatchId = m.matchid
	GROUP BY YEAR(m.eventdate), MONTH(m.eventdate)
	ORDER BY YEAR(m.eventdate), MONTH(m.eventdate)

