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
	Optional : Check datetime for Active Range

	 select min(m.eventdate) AS minDateActive
	 from match m  with(nolock)

	 select min(m.eventdate) AS minDate14, max(m.eventdate)  AS maxDate14
	 from match14 m  with(nolock)

	 2021-04-08: Move Cricket to ResultDetailOS
	 2021-05-31: Release Soccer PinGoal
	 2021-07-19: Move Beach Volleyball to ResultDetailOS
	 2021-08-18: Release Auto settle Virtual Cricket
	 2021-10-07: Move Volleyball to ResultDetailOS
*/


	DECLARE @fromDate DATETIME = '2021-08-01'
			,@toDate  DATETIME = '2021-08-31'
------------------------------------------------------------------------------------------------------------------

	IF OBJECT_ID ('tempdb..#TempMatchInfo' ) IS NOT NULL	DROP TABLE #TempMatchInfo
	IF OBJECT_ID ('tempdb..#TempResultDetail') IS NOT NULL	DROP TABLE #TempResultDetail
	IF OBJECT_ID ('tempdb..#MatchId' ) IS NOT NULL			DROP TABLE #MatchId
	IF OBJECT_ID ('tempdb..#ResultTableSetting' ) IS NOT NULL		DROP TABLE #ResultTableSetting

	CREATE TABLE #TempMatchInfo (
		matchid INT, eventdate VARCHAR(10), sporttype TINYINT, SportName NVARCHAR(100)
		 ,HomeName NVARCHAR(200), AwayName  NVARCHAR(200)
		 ,leagueid INT, leaguename  NVARCHAR(1000), LeagueGroupID SMALLINT, LeagueGroupName NVARCHAR(400), betstatus NVARCHAR(100)
		)

	CREATE TABLE #MatchId (matchid INT, sporttype TINYINT, ResultTable TINYINT, eventdate VARCHAR(10),  betstatus NVARCHAR(100)	)

	CREATE TABLE #TempResultDetail ( MatchId INT, ManualCalculated INT , ManualRefunded INT, AutoSettle INT )

	CREATE TABLE #ResultTableSetting ( sporttype SMALLINT, ResultTable TINYINT )

------------------------------------------------------------------------------------------------------------------
	INSERT INTO #ResultTableSetting ( sporttype, ResultTable) 
		--- 0: match  1:ResultDetail  2:ResultDetailOS  3:ResultDetailOS
		VALUES	 ( 1	, 1 ) --Soccer, PinGoal
				,( 2	, 1 ) --Basketball
				,( 5	, 1 ) --Tennis
				,( 6	, 2 ) --Volleyball
				,( 9	, 2 ) --Badmintion
				,( 43	, 3 ) --E-Sports
				,( 45	, 2 ) --Beach Volleyball
				,( 50	, 2 ) --Cricket

	-- match
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
		AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID = 113 THEN 0 --exclude PinGoal
					ELSE 1 END
		AND m.eventStatus = 'completed'
		AND m.sporttype <= 99
	
	--match14
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
		AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID = 113 THEN 0 --exclude PinGoal
					ELSE 1 END
		AND m.eventStatus = 'completed'
		AND m.sporttype <= 99

	--match_bk
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
		AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID = 113 THEN 0 --exclude PinGoal
					ELSE 1 END
		AND m.eventStatus = 'completed'
		AND m.sporttype <= 99

	INSERT INTO #MatchId (matchid, sporttype, ResultTable, eventdate, betstatus )
	SELECT DISTINCT m.matchid, m.sporttype, ISNULL(ss.ResultTable,0), m.eventdate, m.betstatus
	FROM #TempMatchInfo m
		LEFT JOIN #ResultTableSetting ss ON m.sporttype = ss.sporttype

	--ResultDetail
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
	SELECT	r.MatchId
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
	FROM #MatchId m 
		CROSS APPLY (
						SELECT r.MatchId, r.LastModifyBy, r.SettlementStatusID
						FROM dbo.ResultDetail r WITH(NOLOCK)
						WHERE r.ResultStatusID  IN ( 2, 5) ---settled
							AND r.SettlementStatusID > 0
							AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
							AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0 
																	ELSE 1 
																	END
										  ELSE 1 
										  END --Goal result
							AND m.matchid = r.MatchId
							AND m.ResultTable  = 1
						UNION
						SELECT *
						FROM dbo.ResultDetail14 r WITH(NOLOCK)
						WHERE r.ResultStatusID  IN ( 2, 5) ---settled
							AND r.SettlementStatusID > 0
							AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
							AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0 
																	ELSE 1 
																	END
										  ELSE 1 
										  END --Goal result
							AND m.matchid = r.MatchId
							AND m.ResultTable  = 1
						UNION
						SELECT *
						FROM bodb_archive.dbo.ResultDetail_bk r WITH(NOLOCK)
						WHERE r.ResultStatusID  IN ( 2, 5) ---settled
							AND r.SettlementStatusID > 0
							AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
					) r
	
	GROUP BY r.MatchId

	----ResultDetailES
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
	SELECT	r.MatchId
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCal
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund		
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
	FROM dbo.ResultDetailES r WITH(NOLOCK)
		INNER JOIN #MatchId m ON m.matchid = r.MatchId
	WHERE m.ResultTable = 3
		AND r.ResultStatusID  IN ( 2, 5) ---settled
		AND r.SettlementStatusID > 0
	GROUP BY r.MatchId	
	
	----ResultDetailOS
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
	SELECT	r.MatchId
		, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCal
		, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund		
		, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
	FROM dbo.ResultDetailOS r WITH(NOLOCK)
		INNER JOIN #MatchId m ON m.matchid = r.MatchId
	WHERE m.ResultTable = 2
		AND r.ResultStatusID  IN ( 2, 5) ---settled
		AND r.SettlementStatusID > 0
		AND 1 = CASE WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 0  -- 2021-04-08: Move Cricket to ResultDetailOS
					 WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 0  -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
					 WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 0 --2021-10-07: Move Volleyball to ResultDetailOS
					 ELSE 1
					 END
	GROUP BY r.MatchId		
	
	---Other sports: Result is saved in dbo.match 
	; WITH cte_otherSport (MatchId, ManualCal, ManualRefund, IsAuto) AS 
	(
		SELECT
			m.MatchId
			, CASE WHEN  m.betstatus = 'Refund;' THEN 0 ELSE 1 END	AS ManualCal
			, CASE WHEN  m.betstatus = 'Refund;' THEN 1 ELSE 0 END	AS ManualRefund
			, 0 AS IsAuto
		FROM #MatchId m
		WHERE 1 = CASE WHEN m.ResultTable = 0 THEN 1
					   WHEN m.sporttype = 50 AND m.eventdate < '2021-04-08' THEN 1 -- 2021-04-08: Move Cricket to ResultDetailOS
					   WHEN m.sporttype = 45 AND m.eventdate < '2021-07-19' THEN 1 -- 2021-07-19: Move Beach Volleyball to ResultDetailOS
					   WHEN m.sporttype = 6	AND m.eventdate < '2021-10-07' THEN 1 --2021-10-07: Move Volleyball to ResultDetailOS
					ELSE 0 END
		
		-- Table Tennis
		UNION ALL
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
			, CASE WHEN r.MatchId IS NOT NULL THEN 1 ELSE 0 END		AS IsAuto
			FROM #MatchId m
		OUTER APPLY (	--Already Auto settle sucessfully at least 1 time )
						SELECT TOP 1 r.MatchId FROM dbo.AutoPayoutResult r WITH(NOLOCK)
						WHERE m.matchid = r.MatchId 
							AND r.StatusId = 2
							AND m.betstatus <> 'Refund;'
					) r
		WHERE m.sporttype = 18
	)

	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
	SELECT 
	c.MatchId
	, c.ManualCal
	, c.ManualRefund
	, c.IsAuto AS AutoSettle
	FROM cte_otherSport c

	SELECT m.eventdate,   m.sportName ,  m.LeagueGroupName
		, COunt(DISTINCT r.matchid) as Matches
		 , sum(r.ManualCalculated ) as Calculate
		 , sum(r.ManualRefunded ) as Refund
		 , sum(r.AutoSettle) as AutoSettle
		 , sum( ManualCalculated + ManualRefunded + AutoSettle) AS TotalSettledResourceId
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m on r.MatchId = m.matchid
	group by m.eventdate,   m.sportName ,  m.LeagueGroupName
	order by eventdate,  m.sportName ,  m.LeagueGroupName

		
	--Match vs Result	
	select  YEAR(m.eventdate) AS Y
			,MONTH(m.eventdate) AS M	
			,sum( ManualCalculated + ManualRefunded + AutoSettle) as result 
			, count(DISTINCT r.matchid)	as match 
	FROM #TempResultDetail  r
	INNER JOIN #TempMatchInfo m on r.MatchId = m.matchid
	GROUP BY YEAR(m.eventdate), MONTH(m.eventdate)
	order by YEAR(m.eventdate), MONTH(m.eventdate)

	--Match vs Manual cal and Refund
	select   YEAR(m.eventdate) AS Y
			,MONTH(m.eventdate) AS M	
			,sum( ManualCalculated) ManualCalculated 
			,SUM(ManualRefunded) as ManualRefunded 
			,count(DISTINCT r.matchid)	as match 
	FROM #TempResultDetail  r
	INNER JOIN #TempMatchInfo m on r.MatchId = m.matchid
	GROUP BY YEAR(m.eventdate), MONTH(m.eventdate)
	order by YEAR(m.eventdate), MONTH(m.eventdate)

	--Manual vs Auto
	select  YEAR(m.eventdate) AS Y
		,MONTH(m.eventdate) AS M	
		,sum( ManualCalculated + ManualRefunded) as manual 
		,sum( AutoSettle) as auto
	FROM #TempResultDetail  r
	INNER JOIN #TempMatchInfo m on r.MatchId = m.matchid
	GROUP BY YEAR(m.eventdate), MONTH(m.eventdate)
	order by YEAR(m.eventdate), MONTH(m.eventdate)

