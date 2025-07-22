/*<info serverAlias="DBWH-bodb_dwrs" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250722@Max
	Task	  : Integration - Settlement Time Dashboard report [Redmine:#232227]
	DB		  : DBWH-bodb_dwrs
	Revisions:
		- 20250722@Max: Init data [Redmine:#232227]
*/

DECLARE @FromDate       DATETIME = '2025-01-01'
        ,@ToDate        DATETIME = '2025-07-22'
BEGIN
        SET NOCOUNT ON

        CREATE TABLE #tmpData (
                [Year]                                                        INT
                ,[Month]                                                INT
                ,[Date]                                                        DATETIME
                ,[Weekday]                                                VARCHAR(20)
                ,sporttype                                                SMALLINT
                ,sportname                                                NVARCHAR(50)
                ,GroupID                                                INT
                ,GroupName                                                VARCHAR(200)
                ,LeagueName                                                NVARCHAR(500)
                ,matchid                                                INT
                ,hometeam                                                NVARCHAR(100) 
                ,awayteam                                                NVARCHAR(100)
                ,GlobalShowTime                                        DATETIME
                ,keyscoreUser                                        NVARCHAR(50)
                ,SettleAction                                        VARCHAR(20)
                ,SettlementStatus                                VARCHAR(20)
                ,ConfirmStatus                                        VARCHAR(20)
                ,ConfirmDate                                        DATETIME
                ,Step1_WaitforKeyscore_Duration INT
                ,Step2_WaitforSettle_Duration        INT
                ,Step3_Settle_Duration                        INT
                ,IsHold                                                        INT
                ,IsLive                                                        BIT DEFAULT(0)
                ,IsChildMatch                                        BIT
                ,Action                                                        VARCHAR(20)
                ,ActionId                                                INT
                ,ParentID                                                INT 
                ,ChildMatchType                                        TINYINT    
				,LeagueID	INT
        )
        CREATE TABLE #MatchLive(matchid INT)

        ;WITH cteSettlementPerformanceLog
        AS (
                
                SELECT         LeagueId, MatchId, HomeId, AwayId, Kickofftime, GlobalShowtime, Action, ActionId, IsAuto
                                ,AdminId, HomeScore, AwayScore, ConfirmScoreDate, MIN(Starttime) AS Starttime
                                , MIN(Exectime) AS Exectime, MAX(Duration) AS Duration
                                , MIN(CreatedDate) AS CreatedDate
                                , Sporttype, IsHold, rn
                FROM (
                        SELECT ROW_NUMBER() OVER(PARTITION BY ISNULL(sitedbgroupid,0), matchid, action, actionid, homescore, awayscore ORDER BY starttime ) AS rn
                                ,ISNULL(SiteDBGroupId,0) AS SiteDBGroupId
                                ,LeagueId, MatchId, HomeId, AwayId, Kickofftime, GlobalShowtime, Action, ActionId, IsAuto
                                ,AdminId, HomeScore, AwayScore, ConfirmScoreDate, Starttime, Exectime, Duration, CreatedDate, Sporttype, IsHold
                        FROM        bodb_Account.dbo.SettlementPerformanceLog WITH(NOLOCK)
                        WHERE  CreatedDate >= @FromDate
                                        AND ISNULL(sitedbgroupid,0) <> 0
                                        AND Action NOT IN ('CAL-INST-HT', 'CAL-INST-FT')
           
                )s
                WHERE s.rn = 1
                GROUP BY LeagueId, MatchId, HomeId, AwayId, Kickofftime, GlobalShowtime, Action, ActionId, IsAuto
                                ,AdminId, HomeScore, AwayScore, ConfirmScoreDate, Sporttype, IsHold, rn
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
                FROM        bodb_Account.dbo.UserLog_P_SuspenderConfirm u with(nolock)
                WHERE  logdate >= @FromDate
        )
        INSERT INTO #tmpData(Year, Month, Date, Weekday, sporttype, sportname, GroupID, GroupName, LeagueName, matchid, hometeam, awayteam
                , GlobalShowTime, keyscoreUser, SettleAction,        SettlementStatus, ConfirmStatus, ConfirmDate
                , Step1_WaitforKeyscore_Duration, Step2_WaitforSettle_Duration, Step3_Settle_Duration, IsHold, IsChildMatch
                , Action, ActionId, ParentID, ChildMatchType, LeagueID
        )
        SELECT
                YEAR(m.eventdate) [Year]
                ,MONTH(m.eventdate) [Month]
                ,m.eventdate AS [Date]
                ,CASE WHEN DATEPART(DW, m.eventdate) IN (1,7) THEN 'Weekend' ELSE 'Not Weekend' END [Weekday]
                ,l.sporttype
                ,sp.SportName
                ,lg.GroupID
                ,lg.GroupName
                ,l.leaguename
                ,m.matchid
                ,h.teamname AS hometeam
                ,a.teamname  AS awayteam
                ,m.GlobalShowTime
                ,ISNULL(ci.username, '') AS keyscoreUser
                ,CASE
                        WHEN itv.Interval IS NOT NULL THEN itv.Interval
                        WHEN s.Action = 'CAL' AND s.ActionId = 1 THEN 'CAL-HT'
                        ELSE s.Action
                END AS SettleAction
                ,CASE WHEN s.IsAuto        = 1 THEN 'Auto settle' ELSE 'Manual settle' END AS SettlementStatus
                ,CASE WHEN u.matchid is null then 'No confirm' ELSE 'Confirm' END ConfirmStatus 
                ,u.logdate AS ConfirmDate
                -- Duration
                ,ISNULL(CAST(DATEDIFF(MILLISECOND,CASE WHEN Action like 'Inst%' then s.ConfirmScoreDate else u.logdate end, s.Starttime) AS Float), 0) AS 'Step1_WaitforKeyscore_Duration'
                ,CAST(DATEDIFF(MILLISECOND,s.Starttime, s.Exectime) AS Float) AS 'Step2_WaitforSettle_Duration'
                ,CAST(s.Duration AS Float) AS 'Step3_Settle_Duration'
                ,s.IsHold
                ,CASE WHEN m.parentid is null THEN 0 ELSE 1 END AS IsChildMatch
                ,s.Action
                ,s.ActionId
                ,m.ParentID
                ,m.ChildMatchType
				,l.leagueid
        FROM  cteSettlementPerformanceLog s
                INNER JOIN bodb02.dbo.League l with(nolock)
                        on s.LeagueId = l.leagueid
                INNER JOIN bodb02.dbo.LeagueGroup lg (NOLOCK)
                        on l.LeagueGroupID = lg.GroupID
                INNER JOIN bodb02.[dbo].Sports sp (NOLOCK)
                        ON l.sporttype = sp.SportType
                OUTER APPLY (
                        SELECT CASE
                                        WHEN sp.SportType = 2 THEN CASE WHEN s.ActionId = 2 THEN 'OT' ELSE 'Quarter ' END
                                        WHEN sp.SportType = 5 THEN 'Set '
                                        WHEN sp.SportType = 43 THEN 'Map '
                                        WHEN sp.SportType = 50 THEN 'Inning '        
                                        ELSE 'Interval ' 
                                        END + CASE 
                                                        WHEN sp.SportType = 50 AND s.ActionId = 101 THEN '1 Home'
                                                        WHEN sp.SportType = 50 AND s.ActionId = 102 THEN '1 Away'
                                                        WHEN sp.SportType = 50 AND s.ActionId = 103 THEN '2 Home'
                                                        WHEN sp.SportType = 50 AND s.ActionId = 104 THEN '2 Away'
                                                        ELSE CAST(s.ActionId%100 AS VARCHAR)
                                                END
                                AS Interval 
                        WHERE        s.ActionId > 100 
                )itv
                INNER JOIN
                        (SELECT matchid, homeid, awayid, leagueid, eventdate, GlobalShowTime, ParentID, ChildMatchType
                        FROM bodb_account.dbo.match m with(nolock)
                        UNION
                        select matchid, homeid, awayid, leagueid, eventdate, GlobalShowTime, ParentID, ChildMatchType
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
                        FROM        cteSuspenderConfirm u
                        WHERE        s.MatchId = u.matchid
                                        AND u.ActionID = s.ActionId
                                        AND 1 = CASE 
                                                                WHEN l.SportType = 1 AND u.rn = 1 THEN 1
                                                                WHEN l.sporttype <> 1 AND u.rnDESC = 1 THEN 1
                                                                ELSE 0 
                                                        END
                                        AND s.rn = 1
                        )u
                WHERE        s.rn = 1
                                AND m.eventdate >= @FromDate  and m.eventdate <= @ToDate
                                AND 1 = CASE WHEN lg.GroupID = 42 THEN 0 --Virtual
                                                 WHEN sp.sporttype = 43 AND lg.GroupID IN (151,215) THEN 0 --pingoal
                                                 WHEN sp.sporttype = 2 AND lg.GroupID = 122 THEN 0 --pingoal
                                                 WHEN sp.sporttype = 1 AND lg.GroupID IN (74, 108, 113, 252 ) THEN 0  --Virtual Sport Bacarrat,Virtual Futsal, pingoal
                                        ELSE 1
                                        END
                                AND l.isTest = 0
                
        DELETE main
        FROM #tmpData main 
        WHERE        main.sporttype = 18
                        AND main.parentid IS NULL 
                        AND ActionID > 100
                        AND EXISTS (SELECT TOP 1 1 
                                                FROM         #tmpData child 
                                                WHERE         parentid = main.matchid 
                                                                AND 1 = CASE 
                                                                                        WHEN child.ChildMatchType = 12 AND main.ActionId = 101 THEN 1 -- set 1
                                                                                        WHEN child.ChildMatchType = 14 AND main.ActionId = 102 THEN 1 -- set 2
                                                                                        WHEN child.ChildMatchType = 15 AND main.ActionId = 103 THEN 1 -- set 3
                                                                                        WHEN child.ChildMatchType = 16 AND main.ActionId = 104 THEN 1 -- set 4
                                                                                        WHEN child.ChildMatchType = 17 AND main.ActionId = 105 THEN 1 -- set 5
                                                                                        WHEN child.ChildMatchType = 18 AND main.ActionId = 106 THEN 1 -- set 6
                                                                                        WHEN child.ChildMatchType = 19 AND main.ActionId = 107 THEN 1 -- set 7
                                                                                        ELSE 0
                                                                                END
                                        )
                
        INSERT INTO #MatchLive(matchid)
        SELECT        s.matchid
        FROM        bodb_account.dbo.FactSiteWinloss s (NOLOCK)
        WHERE        [RptDate] >= CAST(@FromDate AS DATE) 
                        AND [RptDate] <= CAST(@ToDate AS DATE)
                        AND [CurrencyID] NOT IN (20,27,28)
                        AND s.LiveStatus = 1 -- Live Ticket
                        AND s.matchid IN (SELECT tmp.MatchID
                                                                FROM #tmpData tmp )
        GROUP BY s.matchid
        HAVING SUM(s.betcount) > 0 
        OPTION (RECOMPILE)

        UPDATE        m 
                SET IsLive = 1
        FROM         #MatchLive s (NOLOCK)
                INNER JOIN #tmpData m 
                        ON         s.matchid = m.matchid

	/*Init data from 2025-01-01*/
	INSERT INTO dbo.SettlementPerformanceReport(sporttype, sportname, LeagueID, LeagueName, EventDate, WaitforKeyscore, WaitingTimeInQueue, SiteDBSettleDuration, TotalDuration)
	SELECT t.sporttype
			,t.sportname
			,t.LeagueID
			,t.LeagueName
			,t.Date AS EventDate
			, AVG(CAST (Step1_WaitforKeyscore_Duration as bigint)) as 'WaitforKeyscore'
			, AVG(CAST (Step2_WaitforSettle_Duration as bigint)) 'WaitingTimeInQueue'
			, AVG(CAST (Step3_Settle_Duration as bigint)) 'SiteDBSettleDuration'
			, AVG(CAST ((Step1_WaitforKeyscore_Duration + Step2_WaitforSettle_Duration + Step3_Settle_Duration) as bigint)) 'TotalDuration'
			FROM #tmpData t
	GROUP BY [sporttype],[SportName],LeagueID, LeagueName, Date

	DROP TABLE #MatchLive
	DROP TABLE #tmpData
END