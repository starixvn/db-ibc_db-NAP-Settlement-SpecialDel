/*
	Created: 20200104@Max
	DB: DBDW2/bodb_Adhoc
	Task: This script is used by DW team to get keyscore performance report
*/
USE bodb_Account
GO

;WITH cteSettlementPerformanceLog
AS (
	SELECT ROW_NUMBER() OVER(PARTITION BY matchid, action, homescore, awayscore ORDER BY starttime ) AS rn, *
	FROM	bodb_Account.dbo.SettlementPerformanceLog WITH(NOLOCK)
)
, cteSuspenderConfirm
AS(
	SELECT ROW_NUMBER() OVER(PARTITION BY matchid, actionid ORDER BY logdate ) AS rn
			,ROW_NUMBER() OVER(PARTITION BY matchid, actionid ORDER BY logdate DESC ) AS rnDESC
			,*
	FROM	bodb_Account.dbo.UserLog_P_SuspenderConfirm u with(nolock)
)
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
	,CASE WHEN u.matchid is null then 'No confirm' ELSE 'Confirm' END ConfirmStatus
	-- Duration
	,ISNULL(CAST(DATEDIFF(MILLISECOND,CASE WHEN Action like 'Inst%' then s.ConfirmScoreDate else u.logdate end, s.Starttime) AS Float)/1000, 0) AS 'Step1_WaitforKeyscore_Duration'
	,CAST(DATEDIFF(MILLISECOND,s.Starttime, s.Exectime) AS Float)/1000 AS 'Step2_WaitforSettle_Duration'
	,CAST(s.Duration AS Float)/1000 AS 'Step3_Settle_Duration'
	,s.IsHold 
FROM  cteSettlementPerformanceLog s
	CROSS APPLY (
		SELECT CASE 
				WHEN action = 'CAL-HT' then 1
				WHEN action = 'CAL-FT' then 2
				--WHEN action IN ('CAL-FT', 'CAL', 'CAL-PARLAY') THEN 2
				WHEN action IN ('CAL-FT', 'CAL') THEN 2
				ELSE 0
			END	AS ActionId
	)at
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
				AND u.ActionID = at.ActionId
				AND 1 = CASE 
							WHEN l.SportType = 1 AND u.rn = 1 THEN 1
							WHEN l.sporttype <> 1 AND u.rnDESC = 1 THEN 1
							ELSE 0 
						END
				AND s.rn = 1
		)u
	WHERE s.rn = 1
		AND m.eventdate >= '2020-12-01'  and m.eventdate < '2021-01-01'
		AND l.sporttype  <> 1 -- Other Sport
		and s.Action in('CAL-HT', 'CAL-FT', 'CAL')
		
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
	,[ConfirmStatus] DESC