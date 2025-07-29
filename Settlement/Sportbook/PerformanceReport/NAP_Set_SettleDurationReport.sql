/*<info serverAlias="DBWH-bodb_dwrs" executers="dwrs" viewers="" isFunction="0" isNested="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SettleDurationReport
	@FromDate	DATETIME = NULL
	,@ToDate	DATETIME = NULL
AS
/*
	Created: 20250729@Max
	DB: DBDW/bodb_dwrs
	Task: [Synergy] - Letstalk/HNI - Daily Settlement Time Report

	Revision:
		- 20250729@Max: created SP [Redmine:#234353]

	Param's explaination:
		- @FromDate/ @ToDate: yesterday
					
*/
BEGIN
        SET NOCOUNT ON

		IF @FromDate IS NULL OR @ToDate IS NULL
		BEGIN
			SELECT @FromDate = CONVERT(DATE, DATEADD(DAY, -1, GETDATE()))
				, @ToDate = @FromDate
		END

        CREATE TABLE #tmpData (
                [Year]							INT
                ,[Month]                        INT
                ,[Date]                         DATETIME
                ,[Weekday]                      VARCHAR(20)
                ,sporttype                      SMALLINT
                ,sportname                      NVARCHAR(50)
                ,GroupID                        INT
                ,GroupName                      VARCHAR(200)
                ,LeagueName                     NVARCHAR(500)
                ,matchid                        INT
                ,hometeam                       NVARCHAR(100) 
                ,awayteam                       NVARCHAR(100)
                ,GlobalShowTime					DATETIME
                ,keyscoreUser					NVARCHAR(50)
                ,SettleAction					VARCHAR(20)
                ,SettlementStatus				VARCHAR(20)
                ,ConfirmStatus					VARCHAR(20)
                ,ConfirmDate					DATETIME
                ,Step1_WaitforKeyscore_Duration	INT
                ,Step2_WaitforSettle_Duration	INT
                ,Step3_Settle_Duration          INT
                ,IsHold                         INT
                ,IsLive                         BIT DEFAULT(0)
                ,IsChildMatch                   BIT
                ,Action                         VARCHAR(20)
                ,ActionId						INT
                ,ParentID                       INT 
                ,ChildMatchType                 TINYINT        
        )

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
                , Action, ActionId, ParentID, ChildMatchType
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
                
		--Return data
		SELECT [Date]
            , [SportName]
            , COUNT(matchid) AS MatchCount          
            , AVG(
                CAST(
                  CASE WHEN sporttype = 1 THEN Step1_WaitforKeyscore_Duration + Step2_WaitforSettle_Duration + Step3_Settle_Duration
						WHEN sporttype = 2 AND IsHold = 0 THEN Step1_WaitforKeyscore_Duration + Step2_WaitforSettle_Duration + Step3_Settle_Duration
					END
                AS BIGINT)) 'SettleDuration'
        FROM #tmpData
        WHERE 1 = CASE WHEN sporttype = 2 THEN 1
                       WHEN sporttype = 1
                                        AND GroupName NOT LIKE 'Special%'
                                        AND Action in('CAL-HT', 'CAL-FT')
                                        AND IsHold = 0
                                        AND ConfirmStatus =  'Confirm'
                                        THEN 1
                        ELSE 0
                        END
        GROUP BY [Date], [SportName]

	DROP TABLE #tmpData
END