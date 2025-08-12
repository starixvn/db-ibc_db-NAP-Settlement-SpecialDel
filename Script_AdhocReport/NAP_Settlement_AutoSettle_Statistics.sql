/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Settlement_AutoSettle_Statistics
	@FromDate DATE = '2025-08-01'
	,@ToDate  DATE = '2025-08-07'

AS
/*
	Created by: 20250808@Louisa
	Task: Report Auto rate ( refer to Keyscore Productivity Report #158811)  [Redmine:#235409]
	Server: db061
	DB: dbacc/bodb02

	Revision:
		20250808@Louisa: Create [Redmine:#235409]

	* Note: get data > '2024-05-09'

*/
BEGIN
	DECLARE  @MovebetDate DATE
			,@BUDate DATE

	SELECT @MovebetDate = CONVERT(DATE, VValue)
    FROM dbo.SystemSettings WITH(NOLOCK)
    WHERE VName = 'MovebetDate'

	-- BU
	SELECT @BUDate = CONVERT(DATE, VValue)
    FROM dbo.MBUSettings WITH(NOLOCK)
	where VName like 'BalanceUpDate'

	-------------------------------------------

	IF OBJECT_ID ('tempdb..#TempMatchInfo' ) IS NOT NULL	DROP TABLE #TempMatchInfo
	IF OBJECT_ID ('tempdb..#TempResultDetail') IS NOT NULL	DROP TABLE #TempResultDetail
	IF OBJECT_ID ('tempdb..#MatchId' ) IS NOT NULL			DROP TABLE #MatchId
	IF OBJECT_ID ('tempdb..#ResultTableSetting' ) IS NOT NULL		DROP TABLE #ResultTableSetting
	IF OBJECT_ID ('tempdb..#tmpResourceTableTennis' ) IS NOT NULL		DROP TABLE #tmpResourceTableTennis
	IF OBJECT_ID ('tempdb..#tmpStatistic' ) IS NOT NULL		DROP TABLE #tmpStatistic

	CREATE TABLE #TempMatchInfo (
		matchid INT, eventdate VARCHAR(10), sporttype TINYINT, SportName NVARCHAR(100)
		 ,leagueid INT, leaguename  NVARCHAR(1000), LeagueGroupID SMALLINT, LeagueGroupName NVARCHAR(400), betstatus NVARCHAR(100), [range] tinyint, ParentId INT, ChildMatchType TINYINT
		)

	CREATE TABLE #MatchId (matchid INT, sporttype TINYINT, ResultTable TINYINT, eventdate VARCHAR(10),  betstatus NVARCHAR(100), [range] tinyint, ParentId INT, ChildMatchType TINYINT, HasAuto BIT)
	CREATE TABLE #TempResultDetail ( MatchId INT, ManualCalculate INT , ManualRefunded INT, AutoCalculate INT, AutoRefund INT )
	CREATE TABLE #ResultTableSetting ( sporttype SMALLINT, ResultTable TINYINT, HasAuto BIT  )
	CREATE TABLE #tmpResourceTableTennis (MatchId INT, ResourceId VARCHAR(20), SettlementStatusId TINYINT, LastModifyBy INT, ParentId INT, ChildMatchType TINYINT)
	CREATE TABLE #tmpStatistic ( eventdate DATE, sportName NVARCHAR(100), LeagueType NVARCHAR(100),  LeagueGroupName NVARCHAR(400), CountMatch  INT, ManualCalculate INT, ManualRefunded INT, AutoCalculate INT, AutoRefund INT, TotalSettledResourceId INT)
------------------------------------------------------------------------------------------------------------------
	INSERT INTO #ResultTableSetting ( sporttype, ResultTable, HasAuto)
	SELECT r.sporttype, r.ResultTable, CASE WHEN ISNULL(r.AP_Group,0) between 1 and 999 THEN 1 ELSE 0 END
	FROM DBPRO.bodb02.dbo.SettlementResultTableSetting r WITH(NOLOCK)

	-- match
	IF @toDate > @MovebetDate
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus, [range], ParentId, ChildMatchType )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
				,1 -- match
				,m.ParentID
				,m.ChildMatchType
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND m.eventdate > @MovebetDate and m.eventdate <= @toDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%'  
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID IN (113,252) THEN 0 --exclude PinGoal
						WHEN m.sporttype = 2 AND lg.GroupID = 122 THEN 0 --exclude PinGoal
						WHEN m.sporttype = 43 AND lg.GroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99
	END
	
	--match14
	IF @fromDate <= @MovebetDate 
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus, [range], ParentId, ChildMatchType )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
				,2 -- match14
				,m.ParentID
				,m.ChildMatchType
		FROM dbo.match14 m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND m.eventdate >= @BUDate AND m.eventdate <= @MovebetDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%' 
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID IN (113,252) THEN 0 --exclude PinGoal
						WHEN m.sporttype = 2 AND lg.GroupID = 122 THEN 0 --exclude PinGoal
						WHEN m.sporttype = 43 AND lg.GroupID IN (151,215) THEN 0 --exclude PinGoal, RedCat
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99
	END

	--match_bk
	IF @fromDate < @BUDate
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus, [range], ParentId, ChildMatchType )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
				,3 -- match_bk
				,m.ParentID
				,m.ChildMatchType
		FROM bodb_archive.dbo.match_bk m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND m.eventdate < @BUDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%' 
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID IN ( 113,252) THEN 0 --exclude PinGoal
						 WHEN m.sporttype = 2 AND lg.GroupID = 122 THEN 0 --exclude PinGoal
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
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
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
			
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND m.sporttype <> 18
		GROUP BY r.MatchId

		--ResultDetailES
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
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
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
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

		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND m.sporttype <> 18
		GROUP BY r.MatchId

		--ResultDetailES14
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate , AutoRefund)
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
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
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate , AutoRefund)
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
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

		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund)
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #MatchId m 
			INNER JOIN  bodb_archive.dbo.ResultDetailOS_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND m.[range] = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND m.sporttype <> 18
		GROUP BY r.MatchId

		--ResultDetailES_bk
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  r.SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
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

		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund)
		SELECT	MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  SettlementStatusID = 4 THEN 1 ELSE 0 END )   AS AutoCalculate
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) AND  SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END )   AS AutoRefund
		FROM #tmpResourceTableTennis 
		GROUP BY MatchId
	END
			
	------------------------ Auto for Sports which are not use ResultDetailX-------------------------------
	DECLARE @tmpAuto TABLE (MatchId INT)
	
	INSERT INTO @tmpAuto(MatchId)
	SELECT DISTINCT  m.MatchId
	FROM DBLOG.bodb_customerlog_Archive.dbo.SettlementPerformanceLog p with(nolock)
	INNER JOIN #MatchId m ON p.MatchId = m.matchid
	WHERE	m.HasAuto = 1 
			AND m.ResultTable = 0
			AND p.IsAuto = 1
	
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
	SELECT	m.MatchId
		, CASE 
				WHEN ka.matchid IS NOT NULL THEN 0 
				WHEN m.betstatus = 'Refund;' THEN 0 
				ELSE 1 END	AS ManualCal
		, CASE 
				WHEN ka.matchid IS NOT NULL THEN 0 
				WHEN  m.betstatus = 'Refund;' THEN 1 
				ELSE 0 END	AS ManualRefund
		, CASE WHEN ka.matchid IS NOT NULL THEN 1 ELSE 0 END AS AutoCalculate
		, 0 AS AutoRefund
	FROM #MatchId m
		LEFT JOIN @tmpAuto ka 
			ON m.matchid  = ka.matchid
    WHERE m.HasAuto = 1 AND m.ResultTable = 0 

	------------------------ Other sports: Result is saved in dbo.match -------
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculate, ManualRefunded , AutoCalculate, AutoRefund )
	SELECT	m.MatchId
		, CASE WHEN  m.betstatus = 'Refund;' THEN 0 ELSE 1 END	AS ManualCal
		, CASE WHEN  m.betstatus = 'Refund;' THEN 1 ELSE 0 END	AS ManualRefund
		, 0 AS AutoCalculate
		, 0 AS AutoRefund
	FROM #MatchId m
	WHERE  m.ResultTable = 0 AND m.HasAuto = 0
	
	INSERT INTO #tmpStatistic( eventdate, sportName, LeagueType,  LeagueGroupName, CountMatch, ManualCalculate, ManualRefunded, AutoCalculate, AutoRefund, TotalSettledResourceId)
	SELECT m.eventdate,   m.sportName 
		,case
			when m.LeagueGroupID = 42 THEN 'Virtual'
			when m.LeagueGroupID IN (74, 108, 113, 252) and m.sporttype = 1 then 'Virtual'
			when m.LeagueGroupID in (122) and m.sporttype = 2 then 'Virtual'
			when m.LeagueGroupID in (151) and m.sporttype = 43 then 'Virtual'
			else 'Real'
		end as [LeagueType]
		,  m.LeagueGroupName
		, COUNT(DISTINCT r.matchid) AS Matches
		 ,SUM(r.ManualCalculate ) AS ManualCalculate
		 ,SUM(r.ManualRefunded ) AS ManualRefunded
		 ,SUM(r.AutoCalculate) AS AutoCalculate
		 ,SUM(r.AutoRefund) AS AutoRefund
		 ,SUM( ManualCalculate + ManualRefunded + AutoCalculate + AutoRefund) AS TotalSettledResourceId
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
	

	--Manual vs Auto
	SELECT m.EventDate, LeagueType
				,SUM( ManualCalculate )	AS ManualCalculate
				,SUM( AutoCalculate)	AS AutoCalculate
				,SUM( ManualRefunded)	AS ManualRefund
				,SUM( AutoRefund)		AS AutoRefund		
			FROM #tmpStatistic m
			GROUP BY m.EventDate, LeagueType
	ORDER BY EventDate, LeagueType

	---soccer
	SELECT m.EventDate, SportName, LeagueType
		,SUM( ManualCalculate )	AS ManualCalculate
		,SUM( AutoCalculate)	AS AutoCalculate
		,SUM( ManualRefunded)	AS ManualRefund
		,SUM( AutoRefund)		AS AutoRefund	
	FROM #tmpStatistic m
	WHERE sportName = 'soccer' 
	GROUP BY m.EventDate, sportName, LeagueType
	ORDER BY EventDate, sportName, LeagueType

	---basketball
	SELECT m.EventDate, sportName, LeagueType
		,SUM( ManualCalculate )	AS ManualCalculate
		,SUM( AutoCalculate)	AS AutoCalculate
		,SUM( ManualRefunded)	AS ManualRefund
		,SUM( AutoRefund)		AS AutoRefund			
		FROM #tmpStatistic m
		WHERE sportName =  'basketball' 
		GROUP BY m.EventDate, sportName, LeagueType
	ORDER BY EventDate, sportName, LeagueType

END