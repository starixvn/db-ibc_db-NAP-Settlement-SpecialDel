/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_PerformanceReport
AS
/*
	Created: 20190506@Kathy
	Task : Write User Action Logs to Prepare Keyscore Performance Report [Redmine:#104631]
	DB: DBLOG/bodb_CustomerLog_Archive 
	
	Revision:
		- 20190710@Helen: Settlement Performance Report -  Batch by batch - [Redmine: 100002]
		- 20200818@Kathy: Support for other sports [Redmine:#138281]
		- 20200903@Kathy: Move SP from DBTXN to DBLOG [Redmine:#138281]
		- 20210302@Kathy: Add more logaction [Redmine:#138281]
		- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
		- 20220607@Kathy: correct condition to get cricket match [Redmine:#158811]
		- 20221128@Kathy: Move table single/parlay queue_bk, SettlementPerformanceLog to bodb_CustomerLog_Archive [Redmine:#180941]
*/
BEGIN
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

	CREATE TABLE #tmpINST (
		matchid			INT
		,action			VARCHAR(20)
		,homescore		INT
		,awayscore		INT
		,confirmdate	DATETIME
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

	SELECT @maxdate = MAX(Starttime)
	FROM	dbo.SettlementPerformanceLog WITH (NOLOCK)

	IF @maxdate IS NULL
		SET @maxdate = '2018-01-01'

	INSERT INTO #tmpDATA(matchid, starttime, exectime, duration, isauto, adminid, action, eventdate, sqlcommand)
	SELECT	matchid, starttime, exectime, duration, CASE WHEN adminid = 0 THEN 1 ELSE 0 END AS isauto, adminid, action, eventdate, sqlcommand
	FROM	dbo.Single_Calculate_Queue_bk s WITH (NOLOCK)
	WHERE	action IN ('CAL-HT', 'CAL-FT', 'CAL', 'INST-HT', 'INST-FT')
			AND Starttime > @maxdate
	UNION ALL
	SELECT	matchid, starttime, exectime, duration, CASE WHEN Creator = 0 THEN 1 ELSE 0 END AS isauto, creator, 'CAL-PARLAY' AS action, eventdate, '' AS sqlcommand
	FROM	dbo.Parlay_Calculate_Queue_bk p WITH (NOLOCK)
	WHERE	action = 'CAL'
			AND Starttime > @maxdate

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
		OUTER APPLY(
			SELECT fss.[value]
			FROM STRING_SPLIT(sqlcommand,',') fss 
			WHERE fss.[value] LIKE '%@fth %'
		) h
		OUTER APPLY(
			SELECT fss.[value]
			FROM STRING_SPLIT(sqlcommand,',') fss 
			WHERE fss.[value] LIKE '%@fta %'
		) a
	WHERE l.isTest = 0
		AND 1 = CASE 
					WHEN m.sporttype = 1 THEN 1
					WHEN action IN ('CAL-FT', 'CAL')
						AND d.AdminId <> 0
						AND (
						( d.sqlCommand LIKE '%NAP_Admin_Settlement_1%' AND CHARINDEX('NULL',h.[value]) = 0 AND CHARINDEX('NULL',a.[value]) = 0)
						OR (d.sqlCommand LIKE '%NAP_Admin_Settlement_Profile%' AND d.sqlCommand LIKE '%Resource Id="00"%')
						OR (m.sporttype = 50 AND d.sqlCommand ='')
						) THEN 1
					ELSE 0
				END

	-- get auto setting 
	UPDATE	r
		SET ishold = 1
	FROM	#tmpRESULT r
		CROSS APPLY (
			SELECT	us.MatchID
			FROM	bodb_CustomerLog.dbo.UserLog_Settle us WITH (NOLOCK)
			WHERE	r.matchid = us.MatchID 
					AND us.ActionID IN (81002,81003,81005,81019)
			GROUP BY us.MatchID
			UNION ALL 
			SELECT	us.MatchID
			FROM	dbo.UserLog_Settle us WITH (NOLOCK)
			WHERE	r.matchid = us.MatchID 
					AND us.ActionID IN (81002,81003,81005,81019)
			GROUP BY us.MatchID
		)l

	-- get score for instant
	UPDATE	r	
		SET homescore = fh.homescore
			,awayscore = fa.awayscore
	FROM	#tmpRESULT r
		OUTER APPLY (
			SELECT	LEFT(SUBSTRING(f.[value],charindex('''', f.[value]) + 1, LEN(f.[value])),1) as homescore
			FROM	STRING_SPLIT(sqlcommand, ',') f
			WHERE	f.[value] LIKE '%@homescore%'
		)fh
		OUTER APPLY (
			SELECT	LEFT(SUBSTRING(f.[value],charindex('''', f.[value]) + 1, LEN(f.[value])),1) as awayscore
			FROM	STRING_SPLIT(sqlcommand, ',') f
			WHERE	f.[value] LIKE '%@awayscore%'
		)fa
	WHERE	Action LIKE 'INST%'

	INSERT INTO #tmpINST (matchid, action, homescore, awayscore, confirmdate)
	SELECT	p.matchid
			,CASE WHEN p.typeid = 101 THEN 'INST-HT' ELSE 'INST-FT' END AS action
			,p.homevalue AS homescore
			,p.awayvalue AS awayscore
			,p.createddate AS confirmdate
	FROM	DBPRO.bodb02.dbo.ProviderResultDetail p with (nolock)
		INNER JOIN bodb02.dbo.match m with (nolock)
			ON p.matchid = m.matchid
	WHERE	SourceId = 100
			AND typeid in (101, 102)
			AND sporttype = 1
			AND p.isconfirmed = 1
			AND p.createddate > @maxdate

	UNION ALL
	SELECT	p.matchid
			,CASE WHEN p.typeid = 101 THEN 'INST-HT' ELSE 'INST-FT' END AS action
			,p.homevalue AS homescore
			,p.awayvalue AS awayscore
			,p.createddate AS confirmdate
	FROM	DBARC.bodb_archive.dbo.ProviderResultDetail_bk p with (nolock)
	WHERE	SourceId = 100
			AND typeid in (101, 102)
			AND p.isconfirmed = 1
			AND p.createddate > @maxdate

	SELECT	DISTINCT r.leagueid, r.matchid, r.homeid, r.awayid, r.kickofftime, r.globalshowtime
			,r.action, r.isauto, r.adminid, i.confirmdate,  r.starttime, r.exectime, r.duration, r.homescore, r.awayscore, r.sporttype, r.ishold

	INTO #Final_Result			
	FROM	#tmpRESULT r
		LEFT JOIN #tmpINST i
			ON r.matchid = i.matchid
				AND r.action = i.action
				AND r.homescore = i.homescore
				AND r.awayscore = i.awayscore
	ORDER BY matchid, starttime, confirmdate

	DECLARE @current DATETIME 
	SET @current = GETDATE()

	WHILE (1 = 1)
	BEGIN

		DELETE TOP (5000) 
		FROM #Final_Result 
		OUTPUT   deleted.leagueid, deleted.matchid, deleted.homeid, deleted.awayid, deleted.kickofftime, deleted.globalshowtime
				,deleted.action, deleted.isauto, deleted.adminid, deleted.confirmdate,  deleted.starttime, deleted.exectime, deleted.duration, deleted.homescore, deleted.awayscore, deleted.sporttype, deleted.ishold
		INTO #Result_tmp ( leagueid, matchid, homeid, awayid, kickofftime, globalshowtime
							,action, isauto, adminid, ConfirmScoreDate,  starttime, exectime, duration, homescore, awayscore, sporttype, ishold)				
	
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
	DROP TABLE #tmpINST
	DROP TABLE #tmpRESULT
	DROP TABLE #Final_Result
	DROP TABLE #Result_tmp
END
GO
