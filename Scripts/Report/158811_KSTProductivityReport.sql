/*
	Created by: 20210723@Louisa
	Task: Keyscore Productivity Report [Redmine:#158811]
	Server: db061
	DB: dbacc/bodb02

	Revision:
		20211026@Louisa: Modify for Auto Settle Cricket + get configuration from SettlementResultTableSetting

*/

USE bodb02
GO

/*
	*** Note: Whenever Sporttype transforms settle result from dbo.match to dbo.resultDetailXX, need to update block code "Other sports..."

	 2021-04-08: Move Cricket to ResultDetailOS
	 2021-05-31: Release Soccer PinGoal
	 2021-07-19: Move Beach Volleyball to ResultDetailOS
	 2021-08-18: Release Auto settle Virtual Cricket
	 2021-10-07: Move Volleyball to ResultDetailOS
	 2022-02-17: release Pingoal basketball
	 2022-12-19: release Pingoal ESports
	 2023-04-12: release Table Tennis - move auto from AutoPayoutResultDetail to AutoPayoutResultDetail

	 *** Scope: SportBook
	 *** Exclude: hedge match, child match of Cricket Test Match, test match
	 *** Exclude : result of FastMarkets, Time Machine, Goal Record, Pingoal
*/


	DECLARE @fromDate DATETIME = '2022-05-01'
			,@toDate  DATETIME = '2022-05-31'
			,@maxEventDate14 DATETIME
			,@maxEventDateBK DATETIME

	SELECT @maxEventDate14 = MAX(EventDate) FROM dbo.match14 m WITH(NOLOCK)
	SELECT @maxEventDateBK = MAX(EventDate) FROM bodb_archive.dbo.match_bk m WITH(NOLOCK)

----============|================|=======================================================
	----------
		-------------
					---------
						----------------
										-----------
			-------------------------------------------

	IF OBJECT_ID ('tempdb..#TempMatchInfo' ) IS NOT NULL	DROP TABLE #TempMatchInfo
	IF OBJECT_ID ('tempdb..#TempResultDetail') IS NOT NULL	DROP TABLE #TempResultDetail
	IF OBJECT_ID ('tempdb..#MatchId' ) IS NOT NULL			DROP TABLE #MatchId
	IF OBJECT_ID ('tempdb..#MatchIdAuto' ) IS NOT NULL		DROP TABLE #MatchIdAuto
	IF OBJECT_ID ('tempdb..#ResultTableSetting' ) IS NOT NULL		DROP TABLE #ResultTableSetting

	CREATE TABLE #TempMatchInfo (
		matchid INT, eventdate VARCHAR(10), sporttype TINYINT, SportName NVARCHAR(100)
		 ,HomeName NVARCHAR(200), AwayName  NVARCHAR(200)
		 ,leagueid INT, leaguename  NVARCHAR(1000), LeagueGroupID SMALLINT, LeagueGroupName NVARCHAR(400), betstatus NVARCHAR(100)
		)

	CREATE TABLE #MatchId (matchid INT, sporttype TINYINT, ResultTable TINYINT, eventdate VARCHAR(10),  betstatus NVARCHAR(100)	)
	CREATE TABLE #TempResultDetail ( MatchId INT, ManualCalculated INT , ManualRefunded INT, AutoSettle INT )
	CREATE TABLE #ResultTableSetting ( sporttype SMALLINT, ResultTable TINYINT )
	CREATE TABLE #MatchIdAuto (matchid INT )

------------------------------------------------------------------------------------------------------------------
	INSERT INTO #ResultTableSetting ( sporttype, ResultTable)
	SELECT r.sporttype, r.ResultTable
	FROM DBPRO.bodb02.dbo.SettlementResultTableSetting r (nolock)
	WHERE ResultTable > 0 --- 0: match  1:ResultDetail  2:ResultDetailOS  3:ResultDetailES

	-- match
	IF @toDate > @maxEventDate14
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, HomeName, AwayName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,home.teamname AS HomeName, away.teamname AS AwayName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
		FROM dbo.match m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%'  
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID = 113 THEN 0 --exclude PinGoal
						WHEN m.sporttype = 2 AND lg.GroupID = 122 AND m.eventdate >= '2022-02-17' THEN 0 --exclude PinGoal
						WHEN m.sporttype = 43 AND lg.GroupID = 151 AND m.eventdate >= '2022-12-19' THEN 0 --exclude PinGoal
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99
	END
	
	--match14
	IF @fromDate <= @maxEventDate14 AND @toDate > @maxEventDateBK
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, HomeName, AwayName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,home.teamname AS HomeName, away.teamname AS AwayName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
		FROM dbo.match14 m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%' 
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID = 113 THEN 0 --exclude PinGoal
						WHEN m.sporttype = 2 AND lg.GroupID = 122 AND m.eventdate >= '2022-02-17' THEN 0 --exclude PinGoal
						WHEN m.sporttype = 43 AND lg.GroupID = 151 AND m.eventdate >= '2022-12-19' THEN 0 --exclude PinGoal
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99
	END

	--match_bk
	IF @fromDate < @maxEventDateBK
	BEGIN
		INSERT INTO #TempMatchInfo (matchid , eventdate, sporttype , sportName, HomeName, AwayName, leagueid , leaguename , LeagueGroupID, LeagueGroupName, betstatus )
		SELECT	m.matchid, CONVERT(  VARCHAR(10), m.eventdate, 120 ) AS eventdate
				,m.sporttype, s.SportName
				,home.teamname AS HomeName, away.teamname AS AwayName
				,m.leagueid, l.leaguename, l.LeagueGroupID, lg.GroupName AS LeagueGroupName
				,m.betstatus
		FROM bodb_archive.dbo.match_bk m WITH(NOLOCK)
			INNER JOIN dbo.sports s WITH(NOLOCK) ON m.sporttype = s.SportType
			INNER JOIN League l WITH(NOLOCK) ON m.leagueid = l.leagueid
			INNER JOIN dbo.LeagueGroup lg WITH(NOLOCK) ON l.LeagueGroupID = lg.GroupID
			INNER JOIN dbo.team home WITH(NOLOCK) ON m.homeid = home.teamid
			INNER JOIN dbo.team away WITH(NOLOCK) ON m.awayid =  away.teamid
		WHERE m.eventdate BETWEEN @fromDate AND @toDate
			AND l.isTest = 0 --exclude test match
			AND 1 =  CASE WHEN m.ParentID IS NOT NULL AND ISNULL(m.ChildMatchType,'')  IN( 100, 200) THEN 0 ---exclude hedge match, child match Cricket
					  ELSE 1 END
			AND m.matchcode not like '%hedge%' 
			AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID = 113 THEN 0 --exclude PinGoal
						 WHEN m.sporttype = 2 AND lg.GroupID = 122 AND m.eventdate >= '2022-02-17' THEN 0 --exclude PinGoal
						 WHEN m.sporttype = 43 AND lg.GroupID = 151 AND m.eventdate >= '2022-12-19' THEN 0 --exclude PinGoal
						ELSE 1 END
			AND m.eventStatus = 'completed'
			AND m.sporttype <= 99
	END

	INSERT INTO #MatchId (matchid, sporttype, ResultTable, eventdate, betstatus )
	SELECT DISTINCT m.matchid, m.sporttype, ISNULL(ss.ResultTable,0), m.eventdate, m.betstatus
	FROM #TempMatchInfo m
		LEFT JOIN #ResultTableSetting ss ON m.sporttype = ss.sporttype

	--Result
	IF @toDate > @maxEventDate14
	BEGIN
		--ResultDetail
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN dbo.ResultDetail r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable  = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
			AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0  --Goal result
													ELSE 1 END
							ELSE 1 END 
		GROUP BY r.MatchId
	
		--ResultDetailOS
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND 1 = CASE WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 0  -- 2021-04-08: Move Cricket to ResultDetailOS
						WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 0  -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
						WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 0 --2021-10-07: Move Volleyball to ResultDetailOS
						ELSE 1	END
		GROUP BY r.MatchId

		--ResultDetailES
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailES r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
		GROUP BY r.MatchId
	END
	
	--Result14
	IF @fromDate <= @maxEventDate14 AND @toDate > @maxEventDateBK
	BEGIN
		--ResultDetail14
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN dbo.ResultDetail14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable  = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
			AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0  --Goal result
													ELSE 1 END
							ELSE 1 END
		GROUP BY r.MatchId

		--ResultDetailOS14
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailOS14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND 1 = CASE WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 0  -- 2021-04-08: Move Cricket to ResultDetailOS
						WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 0  -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
						WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 0 --2021-10-07: Move Volleyball to ResultDetailOS
						ELSE 1	END
		GROUP BY r.MatchId

		--ResultDetailES14
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN  dbo.ResultDetailES14 r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
		GROUP BY r.MatchId
	END

	--ResultBK
	IF @fromDate < @maxEventDateBK
	BEGIN
		--ResultDetail_bk
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN bodb_archive.dbo.ResultDetail_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable  = 1
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
			AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0 --Goal result
													ELSE 1 END
							ELSE 1 END 
		GROUP BY r.MatchId

		--ResultDetailOS_bk
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN  bodb_archive.dbo.ResultDetailOS_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 2
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
			AND 1 = CASE WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 0  -- 2021-04-08: Move Cricket to ResultDetailOS
						WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 0  -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
						WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 0 --2021-10-07: Move Volleyball to ResultDetailOS
						ELSE 1	END
		GROUP BY r.MatchId

		--ResultDetailES_bk
		INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
		SELECT	r.MatchId
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
				, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
		FROM #MatchId m 
			INNER JOIN  bodb_archive.dbo.ResultDetailES_bk r WITH(NOLOCK) ON m.matchid = r.MatchID
		WHERE m.ResultTable = 3
			AND r.ResultStatusID  IN ( 2, 5) ---settled
			AND r.SettlementStatusID > 0
			AND m.matchid = r.MatchId
		GROUP BY r.MatchId
	END

	------------------------ Table Tennis -------------------------------

	INSERT INTO #MatchIdAuto (matchid)	
	SELECT DISTINCT r.MatchId 
	FROM DBLOG.bodb_customerlog_Archive.dbo.SettlementPerformanceLog p with(nolock)
	WHERE p.starttime BETWEEN @fromDate AND @toDate
		AND p.sporttype = 18
		AND p.IsAuto = 1

	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
	SELECT
			m.MatchId
			, CASE WHEN  r.MatchId IS NOT NULL THEN 0 
					WHEN m.betstatus = 'Refund;' THEN 0 
					ELSE 1 
					END	AS ManualCal
			, CASE WHEN  r.MatchId IS NOT NULL THEN 0
				   WHEN  m.betstatus = 'Refund;' THEN 1 
				   ELSE 0 
				   END	AS ManualRefund
			, CASE WHEN r.MatchId IS NOT NULL THEN 1 
					ELSE 0
					END AS IsAuto
			FROM #MatchId m
		OUTER APPLY (	
						SELECT r.MatchId FROM #MatchIdAuto r
						WHERE m.matchid = r.MatchId
							AND m.betstatus <> 'Refund;'
					) r
		WHERE m.sporttype = 18
	
	------------------------ Other sports: Result is saved in dbo.match -------
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
	SELECT	m.MatchId
		, CASE WHEN  m.betstatus = 'Refund;' THEN 0 ELSE 1 END	AS ManualCal
		, CASE WHEN  m.betstatus = 'Refund;' THEN 1 ELSE 0 END	AS ManualRefund
		, 0 AS IsAuto
	FROM #MatchId m
	WHERE m.sporttype <> 18
		AND 1 = CASE WHEN m.ResultTable = 0 THEN 1
					WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 1 -- 2021-04-08: Move Cricket to ResultDetailOS
					WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 1 -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
					WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 1 --2021-10-07: Move Volleyball to ResultDetailOS
				ELSE 0 END

	SELECT m.eventdate,   m.sportName ,  m.LeagueGroupName
		, COUNT(DISTINCT r.matchid) AS Matches
		 ,SUM(r.ManualCalculated ) AS ManualCalculated
		 ,SUM(r.ManualRefunded ) AS ManualRefunded
		 ,SUM(r.AutoSettle) AS AutoSettle
		 ,SUM( ManualCalculated + ManualRefunded + AutoSettle) AS TotalSettledResourceId
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m ON r.MatchId = m.matchid
	GROUP BY m.eventdate,   m.sportName ,  m.LeagueGroupName
	ORDER BY eventdate,  m.sportName ,  m.LeagueGroupName

		
	--Match vs Result	
	SELECT  YEAR(m.eventdate) AS Y
			,MONTH(m.eventdate) AS M	
			,SUM( ManualCalculated + ManualRefunded + AutoSettle) AS TotalSettledResourceId 
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
		,SUM( AutoSettle) AS AutoSettle
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m ON r.MatchId = m.matchid
	GROUP BY YEAR(m.eventdate), MONTH(m.eventdate)
	ORDER BY YEAR(m.eventdate), MONTH(m.eventdate)

