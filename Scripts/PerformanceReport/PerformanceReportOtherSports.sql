/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20200804@Kathy
	Task : Write User Action Logs to Prepare Keyscore Performance Report for other sports [Redmine:#104631]
	DB: DBTXN/bodb02
	
	Revision:

*/
USE bodb02
GO
DECLARE @maxdate DATETIME

CREATE TABLE #tmpDATA (
	matchid		INT
	,starttime	DATETIME
	,exectime	DATETIME
	,duration	INT
	,adminid	INT
	,isauto		BIT
	,action		VARCHAR(20)
	,eventdate	DATETIME
	,sqlcommand VARCHAR(MAX)
)

CREATE TABLE #tmpRESULT (
	leagueid		INT
	,homeid			INT
	,awayid			INT
	,kickofftime	DATETIME
	,globalshowtime DATETIME
	,matchid		INT
	,starttime		DATETIME
	,exectime		DATETIME
	,duration		INT
	,action			VARCHAR(20)
	,eventdate		DATETIME
	,sqlcommand		VARCHAR(MAX)
	,isauto			BIT
	,adminid		INT
)

CREATE TABLE #Result_tmp(
	[LeagueId] [int] NULL,
	[MatchId] [int] NULL,
	[HomeId] [int] NULL,
	[AwayId] [int] NULL,
	[Kickofftime] [datetime] NULL,
	[GlobalShowtime] [datetime] NULL,
	[Action] [varchar](20) NULL,
	[IsAuto] [bit] NULL,
	[AdminId] [int] NULL,
	[Starttime] [datetime] NULL,
	[Exectime] [datetime] NULL,
	[Duration] [int] NULL
)

SELECT @maxdate = '2020-01-01'

INSERT INTO #tmpDATA(matchid, starttime, exectime, duration, isauto, adminid, action, eventdate, sqlcommand)
SELECT	matchid, starttime, exectime, duration, CASE WHEN adminid = 0 THEN 1 ELSE 0 END AS isauto, adminid, action, eventdate, sqlcommand
FROM	dbo.Single_Calculate_Queue_bk s WITH (NOLOCK)
	OUTER APPLY(
	SELECT fss.val
	FROM dbo.f_SplitString(sqlcommand,',') fss 
	WHERE fss.val LIKE '%@fth %'
) h
	OUTER APPLY(
		SELECT fss.val
		FROM dbo.f_SplitString(sqlcommand,',') fss 
		WHERE fss.val LIKE '%@fta %'
	) a
WHERE	action IN ('CAL-FT', 'CAL')
		AND AdminId <> 0
		AND Starttime >= @maxdate
		AND (
		( s.sqlCommand LIKE '%NAP_Admin_Settlement_1%' AND CHARINDEX('NULL',h.val) = 0 AND CHARINDEX('NULL',a.val) = 0)
		OR (s.sqlCommand LIKE '%NAP_Admin_Settlement_Profile%' AND s.sqlCommand LIKE '%Resource Id="00"%')
		)
UNION ALL
SELECT	matchid, starttime, exectime, duration, CASE WHEN Creator = 0 THEN 1 ELSE 0 END AS isauto, creator, 'CAL-PARLAY' AS action, eventdate, '' AS sqlcommand
FROM	dbo.Parlay_Calculate_Queue_bk p WITH (NOLOCK)
WHERE	action = 'CAL'
		AND Creator <> 0
		AND Starttime >= @maxdate
option (maxrecursion 0)

INSERT INTO #tmpRESULT (leagueid, homeid, awayid, kickofftime, globalshowtime, matchid
		,starttime, exectime, duration, action, eventdate, sqlcommand, isauto, adminid
	)
SELECT	m.leagueid, m.homeid, m.awayid, m.kickofftime, m.globalshowtime
		,d.matchid ,d.starttime, d.exectime, d.duration, d.action, d.eventdate, d.sqlcommand, d.isauto, d.adminid
FROM	#tmpDATA d
	CROSS APPLY (
		SELECT	matchid, leagueid, homeid, awayid, kickofftime, globalshowtime
		FROM	dbarc.bodb_archive.dbo.match_bk m WITH (NOLOCK)
		WHERE	sporttype <> 1
				AND matchid = d.matchid
				AND matchcode not like '%hedge%'
			
		UNION ALL
		SELECT  matchid, leagueid, homeid, awayid, kickofftime, globalshowtime
		FROM	dbo.match14 m WITH (NOLOCK)
		WHERE	sporttype = 1
				AND matchid = d.matchid
				AND matchcode not like '%hedge%'

		UNION ALL
		SELECT  matchid, leagueid, homeid, awayid, kickofftime, globalshowtime
		FROM	dbo.match m WITH (NOLOCK)
		WHERE	sporttype = 1
				AND matchid = d.matchid	
				AND matchcode not like '%hedge%'	
	) m
	INNER JOIN dbo.League l WITH (NOLOCK)
		ON m.leagueid = l.leagueid
WHERE l.isTest = 0
	

DECLARE @current DATETIME 
SET @current = GETDATE()

WHILE (1 = 1)
BEGIN

	DELETE TOP (5000) 
	FROM #tmpRESULT 
	OUTPUT   deleted.leagueid, deleted.matchid, deleted.homeid, deleted.awayid, deleted.kickofftime, deleted.globalshowtime
			,deleted.action, deleted.isauto, deleted.adminid, deleted.starttime, deleted.exectime, deleted.duration
	INTO #Result_tmp ( leagueid, matchid, homeid, awayid, kickofftime, globalshowtime
						,action, isauto, adminid,  starttime, exectime, duration)				
	
	IF @@ROWCOUNT = 0 BREAK
	
	INSERT INTO dbo.SettlementPerformanceLog (LeagueId, MatchId, HomeId, AwayId, Kickofftime, GlobalShowtime
											,Action, IsAuto, AdminId, Starttime, Exectime, Duration
											, CreatedDate)
	
	SELECT leagueid, matchid, homeid, awayid, kickofftime, globalshowtime
			,action, isauto, adminid,  starttime, exectime, duration, @current
	FROM #Result_tmp
	
	TRUNCATE TABLE #Result_tmp
	
	WAITFOR DELAY '00:00:00:010'
	
END
DROP TABLE #tmpDATA
DROP TABLE #tmpRESULT
DROP TABLE #Result_tmp
GO
