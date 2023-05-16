/*<info serverAlias="DBWH-bodb_dwrs" executers="dwrs" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_PerformanceReportSel
	@FromDate	DATETIME
	,@ToDate	DATETIME
AS
/*
	Created: 20200104@Max
	DB: DBDW/bodb_Adhoc
	Task: Get keyscore performance report

	Revision:
		- 20210316@Kathy: created SP [Redmine:#138281]
		- 20230322@Louisa: support get result Game/Set/Interval [Redmine:#182007]
		- 20230515@Kathy: fix bug: rollback code from cross apply to outer apply
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tmpData (
		[Year]							INT
		,[Month]						INT
		,[Date]							DATETIME
		,[Weekday]						VARCHAR(20)
		,sporttype						SMALLINT
		,sportname						NVARCHAR(50)
		,GroupName						VARCHAR(200)
		,LeagueName						NVARCHAR(500)
		,matchid						INT
		,hometeam						NVARCHAR(100) 
		,awayteam						NVARCHAR(100)
		,GlobalShowTime					DATETIME
		,keyscoreUser					NVARCHAR(50)
		,SettleAction					VARCHAR(20)
		,SettlementStatus				VARCHAR(20)
		--,ConfirmStatus					VARCHAR(20)
		,Step1_WaitforKeyscore_Duration INT
		,Step2_WaitforSettle_Duration	INT
		,Step3_Settle_Duration			INT
		,IsHold							INT
	)

	;WITH cteSettlementPerformanceLog
	AS (
		SELECT ROW_NUMBER() OVER(PARTITION BY matchid, action, homescore, awayscore ORDER BY starttime ) AS rn
			,LeagueId, MatchId, HomeId, AwayId, Kickofftime, GlobalShowtime, Action ,ActionId, IsAuto
			,AdminId, HomeScore, AwayScore, ConfirmScoreDate, Starttime, Exectime, Duration, CreatedDate, Sporttype, IsHold
		FROM	bodb_Account.dbo.SettlementPerformanceLog WITH(NOLOCK)
	)
	, cteSuspenderConfirm
	AS(
		SELECT ROW_NUMBER() OVER(PARTITION BY matchid, actionid ORDER BY logdate ) AS rn
				,ROW_NUMBER() OVER(PARTITION BY matchid, actionid ORDER BY logdate DESC ) AS rnDESC
				,u.matchid
				,u.ActionID
				,u.SuspenderID
				,u.homescore
				,u.awayscore
				,u.betstatus
				,u.logdate
		FROM	bodb_Account.dbo.UserLog_P_SuspenderConfirm u with(nolock)
	)
	INSERT INTO #tmpData(Year, Month, Date, Weekday, sporttype, sportname, GroupName, LeagueName, matchid, hometeam, awayteam
		, GlobalShowTime, keyscoreUser, SettleAction,	SettlementStatus 
		, Step1_WaitforKeyscore_Duration, Step2_WaitforSettle_Duration, Step3_Settle_Duration, IsHold)
	SELECT
		YEAR(m.eventdate) [Year]
		,MONTH(m.eventdate) [Month]
		,m.eventdate AS [Date]
		,CASE WHEN DATEPART(DW, m.eventdate) IN (1,7) THEN 'Weekend' ELSE 'Not Weekend' END [Weekday]
		--
		,l.sporttype
		,sp.SportName
		,lg.GroupName
		,l.leaguename
		,m.matchid
		,h.teamname AS hometeam
		,a.teamname  AS awayteam
		,m.GlobalShowTime
		,ISNULL(ci.username, '') AS keyscoreUser
		,s.Action AS SettleAction
		--
		,CASE WHEN s.IsAuto	= 1 THEN 'Auto settle' ELSE 'Manual settle' END AS SettlementStatus
		/*,CASE WHEN u.matchid is null then 'No confirm' ELSE 'Confirm' END ConfirmStatus */
		-- Duration
		,ISNULL(CAST(DATEDIFF(MILLISECOND,CASE WHEN Action like 'Inst%' then s.ConfirmScoreDate else u.logdate end, s.Starttime) AS Float)/1000, 0) AS 'Step1_WaitforKeyscore_Duration'
		,CAST(DATEDIFF(MILLISECOND,s.Starttime, s.Exectime) AS Float)/1000 AS 'Step2_WaitforSettle_Duration'
		,CAST(s.Duration AS Float)/1000 AS 'Step3_Settle_Duration'
		,s.IsHold 
	FROM  cteSettlementPerformanceLog s
		INNER JOIN bodb02.dbo.League l with(nolock)
			on s.LeagueId = l.leagueid
		INNER JOIN bodb02.dbo.LeagueGroup lg (NOLOCK)
			on l.LeagueGroupID = lg.GroupID
		INNER JOIN bodb02.[dbo].Sports sp (NOLOCK)
			ON l.sporttype = sp.SportType
		INNER JOIN
			(SELECT matchid, homeid, awayid, leagueid, eventdate, GlobalShowTime
			FROM bodb_account.dbo.match m with(nolock)
			UNION
			select matchid, homeid, awayid, leagueid, eventdate, GlobalShowTime
			from bodb_archive.dbo.match  with(nolock)
		) m
			on s.matchid = m.matchid
		INNER JOIN bodb02.dbo.team h with(nolock)
			on h.teamid = m.homeid
		INNER JOIN bodb02.dbo.team a with(nolock)
			on a.teamid = m.awayid
		LEFT JOIN bodb02.dbo.custinfo ci with(nolock)
			on ci.custid = s.AdminId
		OUTER APPLY
			(SELECT *
			FROM	cteSuspenderConfirm u
			WHERE	s.MatchId = u.matchid
					AND u.ActionID = s.ActionId
					AND 1 = CASE 
								WHEN l.SportType = 1 AND u.rn = 1 THEN 1
								WHEN l.sporttype <> 1 AND u.rnDESC = 1 THEN 1
								ELSE 0 
							END
					AND s.rn = 1
			)u
		WHERE	s.rn = 1
				AND m.eventdate >= @FromDate  and m.eventdate <= @ToDate
				AND 1 = CASE WHEN lg.GroupID = 42 THEN 0 --Virtual
						 WHEN sp.sporttype = 43 AND lg.GroupID = 151 THEN 0 --pingoal
						 WHEN sp.sporttype = 2 AND lg.GroupID = 122 THEN 0 --pingoal
						 WHEN sp.sporttype = 1 AND lg.GroupID IN ( 74, 108, 113 ) THEN 0  --Virtual Sport Bacarrat,Virtual Futsal, pingoal
					ELSE 1
					END				 
				AND s.Action <> 'CAL-PARLAY'
		

		SELECT *
			,Step1_WaitforKeyscore_Duration + Step2_WaitforSettle_Duration + Step3_Settle_Duration AS Total
		FROM #tmpData
		WHERE sporttype = 1
		ORDER BY [Year] DESC 
		,[Month] DESC
		,[Date] DESC
		,[Weekday] DESC
		,[sporttype] DESC
		,[SportName] DESC
		,[GroupName] DESC
		,[leaguename] DESC
		,[matchid] DESC
		,[hometeam] DESC
		,[awayteam] DESC
		,[GlobalShowTime] DESC
		,[keyscoreUser] DESC
		,[SettleAction] DESC
		,[SettlementStatus] DESC 

		SELECT *
			,Step1_WaitforKeyscore_Duration + Step2_WaitforSettle_Duration + Step3_Settle_Duration AS Total
		FROM #tmpData
		WHERE sporttype <> 1
		ORDER BY [Year] DESC 
		,[Month] DESC
		,[Date] DESC
		,[Weekday] DESC
		,[sporttype] DESC
		,[SportName] DESC
		,[GroupName] DESC
		,[leaguename] DESC
		,[matchid] DESC
		,[hometeam] DESC
		,[awayteam] DESC
		,[GlobalShowTime] DESC
		,[keyscoreUser] DESC
		,[SettleAction] DESC
		,[SettlementStatus] DESC 
END