/*<info serverAlias="DBLOG-bodb_Customerlog" executers="" viewers="" isFunction="0"></info>*/

DECLARE @fromdate DATETIME = '2021-12-01'
		,@todate DATETIME = '2022-06-04 23:59:58.200'

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
	sporttype		SMALLINT
	,leagueid		INT
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
	,homescore		INT
	,awayscore		INT
	,isauto			BIT
	,adminid		INT
	,ishold			BIT DEFAULT (0)

)

CREATE TABLE #Result_tmp(
	[Sporttype] [smallint] NULL,
	[LeagueId] [int] NULL,
	[MatchId] [int] NULL,
	[HomeId] [int] NULL,
	[AwayId] [int] NULL,
	[Kickofftime] [datetime] NULL,
	[GlobalShowtime] [datetime] NULL,
	[Action] [varchar](20) NULL,
	[IsAuto] [bit] NULL,
	[AdminId] [int] NULL,
	[HomeScore] [int] NULL,
	[AwayScore] [int] NULL,
	[ConfirmScoreDate] [datetime] NULL,
	[Starttime] [datetime] NULL,
	[Exectime] [datetime] NULL,
	[Duration] [int] NULL,
	[IsHold] [bit] NULL

)

INSERT INTO #tmpDATA(matchid, starttime, exectime, duration, isauto, adminid, action, eventdate, sqlcommand)
SELECT	matchid, starttime, exectime, duration, CASE WHEN adminid = 0 THEN 1 ELSE 0 END AS isauto, adminid, action, eventdate, sqlcommand
FROM	dbo.Single_Calculate_Queue_bk s WITH (NOLOCK)
WHERE	action IN ( 'CAL')
		AND sqlCommand = ''
		AND Starttime BETWEEN @fromdate AND @todate

INSERT INTO #tmpRESULT ( leagueid, homeid, awayid, kickofftime, globalshowtime, matchid
		,starttime, exectime, duration, action, eventdate, sqlcommand, isauto, adminid, sporttype
	)
SELECT	 m.leagueid, m.homeid, m.awayid, m.kickofftime, m.globalshowtime
		,d.matchid ,d.starttime, d.exectime, d.duration, d.action, d.eventdate, d.sqlcommand, d.isauto, d.adminid, m.sporttype
FROM	#tmpDATA d
	CROSS APPLY (
		SELECT	matchid, sporttype, leagueid, homeid, awayid, kickofftime, globalshowtime
		FROM	dbarc.bodb_archive.dbo.match_bk m WITH (NOLOCK)
		WHERE	matchid = d.matchid
				AND matchcode not like '%hedge%'  			
		UNION ALL
		SELECT  matchid, sporttype, leagueid, homeid, awayid, kickofftime, globalshowtime
		FROM	bodb02.dbo.match14 m WITH (NOLOCK)
		WHERE	matchid = d.matchid
				AND matchcode not like '%hedge%'	
		UNION ALL
		SELECT  matchid, sporttype, leagueid, homeid, awayid, kickofftime, globalshowtime
		FROM	bodb02.dbo.match m WITH (NOLOCK)
		WHERE	matchid = d.matchid	
				AND matchcode not like '%hedge%'	
	) m
	INNER JOIN bodb02.dbo.League l WITH (NOLOCK)
		ON m.leagueid = l.leagueid
	
WHERE l.isTest = 0
	AND m.sporttype = 50 
	AND d.sqlCommand =''

-- get auto setting 
UPDATE	r
	SET ishold = 1
FROM	#tmpRESULT r
	CROSS APPLY (
		SELECT	us.MatchID
		FROM	dbo.UserLog_Settle us WITH (NOLOCK)
		WHERE	r.matchid = us.MatchID 
				AND us.ActionID IN (81002,81003,81005,81019)
		GROUP BY us.MatchID
		UNION ALL 
		SELECT	us.MatchID
		FROM	bodb_CustomerLog_Archive.dbo.UserLog_Settle us WITH (NOLOCK)
		WHERE	r.matchid = us.MatchID 
				AND us.ActionID IN (81002,81003,81005,81019)
		GROUP BY us.MatchID
	)l

DECLARE @current DATETIME 
SET @current = GETDATE()

WHILE (1 = 1)
BEGIN

	DELETE TOP (5000) 
	FROM #tmpRESULT 
	OUTPUT   deleted.leagueid, deleted.matchid, deleted.homeid, deleted.awayid, deleted.kickofftime, deleted.globalshowtime
			,deleted.action, deleted.isauto, deleted.adminid,  deleted.starttime, deleted.exectime, deleted.duration, deleted.homescore, deleted.awayscore, deleted.sporttype, deleted.ishold
	INTO #Result_tmp ( leagueid, matchid, homeid, awayid, kickofftime, globalshowtime
						,action, isauto, adminid,  starttime, exectime, duration, homescore, awayscore, sporttype, ishold)				
	
	IF @@ROWCOUNT = 0 BREAK
	
	INSERT INTO dbo.SettlementPerformanceLog (LeagueId, MatchId, HomeId, AwayId, Kickofftime, GlobalShowtime
											,Action, IsAuto, AdminId, ConfirmScoreDate, Starttime, Exectime, Duration
											, HomeScore, AwayScore, CreatedDate, sporttype, ishold )	
	SELECT leagueid, matchid, homeid, awayid, kickofftime, globalshowtime
			,action, isauto, adminid, ConfirmScoreDate,  starttime, exectime, duration, homescore, awayscore, @current, sporttype, ishold
	FROM #Result_tmp
	
	TRUNCATE TABLE #Result_tmp
	
	WAITFOR DELAY '00:00:00:010'
	
END
DROP TABLE #tmpDATA
DROP TABLE #tmpRESULT
DROP TABLE #Result_tmp


