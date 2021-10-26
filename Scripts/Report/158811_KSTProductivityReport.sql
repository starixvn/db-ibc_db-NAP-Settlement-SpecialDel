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
*/


	DECLARE @fromDate DATETIME = '2021-08-01'
			,@toDate  DATETIME = '2021-08-31'
------------------------------------------------------------------------------------------------------------------

	IF OBJECT_ID ('tempdb..#TempMatchInfo' ) IS NOT NULL	DROP TABLE #TempMatchInfo
	IF OBJECT_ID ('tempdb..#TempResultDetail') IS NOT NULL	DROP TABLE #TempResultDetail
	IF OBJECT_ID ('tempdb..#MatchId' ) IS NOT NULL			DROP TABLE #MatchId

	CREATE TABLE #TempMatchInfo (
		matchid INT, eventdate VARCHAR(10), sporttype TINYINT, SportName NVARCHAR(100)
		 ,HomeName NVARCHAR(200), AwayName  NVARCHAR(200)
		 ,leagueid INT, leaguename  NVARCHAR(1000), LeagueGroupID SMALLINT, LeagueGroupName NVARCHAR(400), betstatus NVARCHAR(100)
		)

	CREATE TABLE #MatchId (matchid INT, sporttype TINYINT, ResultTable TINYINT)

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
		AND 1 = CASE WHEN m.sporttype = 1 AND lg.GroupID = 113 THEN 0 --PinGoal
					ELSE 1 END
		AND m.eventStatus = 'completed'
		AND m.sporttype <= 99
			

	INSERT INTO #MatchId (matchid, sporttype, ResultTable) 
	SELECT m.matchid, m.sporttype, ISNULL(ss.ResultTable,0)
	FROM #TempMatchInfo m
		LEFT JOIN #ResultTableSetting ss ON m.sporttype = ss.sporttype

	--ResultDetail
	INSERT INTO #TempResultDetail ( MatchId  , ManualCalculated, ManualRefunded , AutoSettle )
	SELECT	r.MatchId
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCalculated
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund
			, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
	FROM dbo.ResultDetail r WITH(NOLOCK)
		INNER JOIN #MatchId m ON m.matchid = r.MatchId
	WHERE m.ResultTable  = 1
		AND r.ResultStatusID  IN ( 2, 5) ---settled
		AND r.SettlementStatusID > 0
		AND r.ResourceId not LIKE '22[1-9]%'	--exclude Fastmarkets, Time Machine
		AND 1 =  CASE WHEN m.sporttype = 1 THEN CASE WHEN r.ResourceId IN ('09','127F','127L','14F','14L') THEN 0 ELSE 1 END
						ELSE 1 END
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
	SELECT
	r.MatchId
	, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND r.SettlementStatusID = 4 THEN 1 ELSE 0 END ) AS ManualCal
	, SUM(CASE WHEN ISNULL(LastModifyBy, 1) NOT IN ( 0,  111) AND  r.SettlementStatusID IN (1,2,3,5,6,7) THEN 1 ELSE 0 END ) AS ManualRefund		
	, SUM(CASE WHEN ISNULL(LastModifyBy, 1) IN ( 0,  111) THEN 1 ELSE 0 END ) AS AutoSettle
	FROM dbo.ResultDetailOS r WITH(NOLOCK)
		INNER JOIN #MatchId m ON m.matchid = r.MatchId
	WHERE m.ResultTable = 2
		AND r.ResultStatusID  IN ( 2, 5) ---settled
		AND r.SettlementStatusID > 0
	GROUP BY r.MatchId		
	
	---Other sports: Result is saved in dbo.match 
	; WITH cte_otherSport (MatchId, IsRefunded, IsAuto) AS 
	(
		SELECT
			m.MatchId
			, CASE WHEN  m.betstatus = 'Refund;' THEN 1 ELSE 0 END	AS IsRefunded
			, 0 AS IsAuto
		FROM #TempMatchInfo m
		WHERE m.sporttype NOT IN ( SELECT sporttype FROM #ResultTableSetting )
		
		-- Table Tennis
		UNION ALL
		SELECT
			m.MatchId
			, CASE WHEN  m.betstatus = 'Refund;' THEN 1 ELSE 0 END	AS IsRefunded
			, CASE WHEN r.MatchId IS NOT NULL THEN 1 ELSE 0 END		AS IsAuto
			FROM #TempMatchInfo m
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
	, CASE c.IsRefunded WHEN 1 THEN 0 ELSE 1 END AS ManualCalculated
	, c.IsRefunded
	, c.IsAuto AS AutoSettle
	FROM cte_otherSport c


	--SELECT m.matchid ,  m.eventdate,  m.sporttype ,  m.sportName,  m.HomeName,  m.AwayName,  m.leagueid ,  m.leaguename ,  m.LeagueGroupID,  m.LeagueGroupName
	--	 , r.ManualCalculated 
	--	 , r.ManualRefunded 
	--	 , r.AutoSettle
	--	 , ManualCalculated + ManualRefunded + AutoSettle AS TotalSettledResourceId
	--FROM #TempResultDetail  r
	--INNER JOIN #TempMatchInfo m on r.MatchId = m.matchid

	SELECT m.eventdate,   m.sportName ,  m.LeagueGroupName
		, COunt(m.matchid) as Matches
		 , sum(r.ManualCalculated ) as Calculate
		 , sum(r.ManualRefunded ) as Refund
		 , sum(r.AutoSettle) as AutoSettle
		 , sum( ManualCalculated + ManualRefunded + AutoSettle) AS TotalSettledResourceId
	FROM #TempResultDetail  r
		INNER JOIN #TempMatchInfo m on r.MatchId = m.matchid
	group by m.eventdate,   m.sportName ,  m.LeagueGroupName
	order by eventdate,  m.sportName ,  m.LeagueGroupName