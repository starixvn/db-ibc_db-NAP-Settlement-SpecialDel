/*
	created: 20200711@Helen
	Task: Internal error report - https://nexdev.net/issues/137375
	DB: dbarc(db061)/bodb_archive
*/
USE bodb_archive
GO
--Step 2: Internal Error -> Refund match 
-- Step 2.1: get message content then check matchid
DECLARE @from datetime, @to datetime
SET @from = '2018-01-01'
SET @to = '2018-01-31'

SELECT 
	CASE 
		WHEN Content_en LIKE '%Due to wrong fixture displayed%considered REFUNDED%' THEN 'Others'
		WHEN  Content_en LIKE '%Due to wrong league name displayed%considered REFUNDED%' THEN 'wrong league name'
		ELSE 'wrong team name' END as Reason
	,ms.matchid
	,ms.Content_en
from 
Db05bk1.bodb_Message_Archive.dbo.[Msg_Archive] ms WITH (NOLOCK)  
--Db05bk1.bodb_Message.dbo.[Msg] ms WITH (NOLOCK) 
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to
	AND (
		-- #1 wrong score
		Content_en LIKE '%Due to wrong league name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong Away team name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong Home team name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong fixture displayed%considered REFUNDED%'
		OR Content_en LIKE '%wrong team name displayed%all bets taken are considered REFUNDED%'
		)
	--AND ms.MatchId > 0
	AND ms.IsTest = 0

-- Step 2.2: get matchid manually base on betstatus: Refund
---Script to check matchid below
/*
DECLARE @led VARCHAR(400)
	, @home VARCHAR(400)
	, @away VARCHAR(400)

select @led='China Basketball Development League (in Chongqing)',@home='Sichuan Reserves',@away='Zhejiang Chouzhou Reserves'

SELECT top 100 m.matchid, eventstatus, m.eventdate, betstatus, leaguename, m.home, m.away
FROM bodb02.dbo.league l WITH (NOLOCK)
	cross apply (select top 100 m.*, h.teamname as home, a.teamname as away
				from match_bk m WITH (NOLOCK)
				--bodb02.dbo.match m WITH (NOLOCK)
				--bodb02.dbo.match14 m WITH (NOLOCK)
				INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
				INNER JOIN bodb02.dbo.team h WITH (NOLOCK) ON h.teamid = m.homeid
				INNER JOIN bodb02.dbo.team a WITH (NOLOCK) ON a.teamid = m.awayid
				where  
					h.teamname LIKE '%' + @home + '%'
					AND a.teamname LIKE '%' + @away + '%'
						and
					betstatus like 'Refund%'
				) as m
WHERE 
--l.leagueid in (78365) --,78366,78367)
--and year(m.eventdate) = 2018 
	l.leaguename LIKE '%' + @led + '%'	
	--AND
	
	--and m.eventdate = '2020-06-26'
order by m.eventdate desc

--select * from bodb02.dbo.team with (nolock) where teamname like '%CHINA FOOTBALL SUPER LEAGUE - CORNERS%'
--select * from 	bodb02.dbo.league l WITH (NOLOCK) where l.leaguename LIKE  '%Beach Volleyball - FIVB Caspian Sea Series Bandar Anzali Tour Men%'
*/
-- Final result
--- missing refund match
/*

matchid		eventstatus	eventdate				betstatus		leaguename
36884064	Completed	2020-06-25 00:00:00.000	Refund;			CLUB FRIENDLY
36813706	completed	2020-06-26 00:00:00.000	Refund;			League of Legends - Turkey Academy League Summer
*/

-- Step 2.3: Final Result: input matchid, reason from step 2.2

CREATE TABLE #match_pre (reason VARCHAR(50), matchid INT)
insert into #match_pre (reason, matchid)
values ('wrong team name',24062178),
('wrong team name',24090344),
('wrong team name',24091087),
('wrong team name',24275152),
('wrong team name',24275178),
('wrong team name',24630162),
('wrong team name',24677718),
('wrong team name',26069860),
('wrong team name',26087414),
('wrong team name',26081902),
('wrong team name',26169388),
('wrong team name',26158825),
('wrong team name',26176728),
('wrong team name',26266215),
('wrong team name',26266217),
('wrong team name',26350266),
('wrong team name',26445965),
('wrong team name',26553303),
('wrong team name',26565655),
('wrong team name',26811294),
('wrong team name',27263827),
('wrong team name',27302788),
('wrong team name',27544902),
('wrong team name',28023952),
('wrong team name',28023967),
('wrong team name',28007544),
('wrong team name',28155700)

create table #match (matchid  INT,reason varchar(50), eventdate datetime,isfinished BIT)
insert into #match (matchid, eventdate, reason)
select m.matchid, m.eventdate, mpr.reason 
from match_bk m (nolock)
	inner join #match_pre mpr on mpr.matchid = m.matchid
	inner join bodb02.dbo.Team h with (nolock) on h.teamid = m.homeid
	inner join bodb02.dbo.Team a with (nolock) on a.teamid = m.awayid
	INNER JOIN bodb02.dbo.League l (nolock) on l.leagueid = m.leagueid
order by eventdate
	
CREATE TABLE #temp_missing (reason varchar(50), matchid INT,sporttype tinyint, sportName nVARCHAR(100), home nvarchar(200), away varchar(200), leaguename varchar(1000), LeagueGroup varchar(200))				

INSERT INTO #temp_missing (matchid,reason, sporttype, sportName, home, away, leaguename, LeagueGroup)				
SELECT DISTINCT d.matchid, d.reason, m.sporttype, m.SportName, m.home, m.away, l.leaguename,case when isnull(l.[Group],'')=''  then 'Others' else l.[Group] end LeagueGroup 				
FROM #match d with (nolock)				
	CROSS APPLY (			
		SELECT	matchid, leagueid, h.teamname as home, a.teamname as away, s.SportName, m.sporttype	
		FROM	dbo.match_bk m WITH (NOLOCK)
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid
			left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid 
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype
			
		WHERE	matchid = d.matchid	
				
		--UNION ALL		
		--SELECT  matchid, leagueid	, h.teamname as home, a.teamname as away	, s.SportName, m.sporttype	
		--FROM	bodb02.dbo.match14 m WITH (NOLOCK)	
		--	left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid
		--	left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid 
		--	left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype	
		--WHERE	matchid = d.matchid	
				
		--UNION ALL		
		--SELECT  matchid, leagueid , h.teamname as home, a.teamname as away, s.SportName, m.sporttype		
		--FROM	bodb02.dbo.match m WITH (NOLOCK)	
		--	left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid
		--	left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid 	
		--	left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype
		--WHERE	matchid = d.matchid	
	) m			
	INNER JOIN bodb02.dbo.League l WITH (NOLOCK)			
		ON m.leagueid = l.leagueid		
WHERE l.isTest = 0	

create table #result (winlostdate datetime, reason varchar(50), matchid INT, sporttype tinyint, sportname varchar(100), home varchar(200), away varchar(200), leaguename varchar(1000), LeagueGroup varchar(200)
				,bet_cnt INT, MemberTO_RM money, House_TO_RM money, ActionName varchar(100))


declare @wld datetime, @matchid INT = 0
while 1=1
begin
	
	update  top (1) m
		set @wld = eventdate
			,@matchid = matchid 
			,isfinished = 1
	from  #match m
	where isfinished is null
	
	if @@ROWCOUNT = 0
	BREAK
	
	INSERT INTO #result (winlostdate, reason, matchid, sporttype, sportname, home, away, leaguename, LeagueGroup, bet_cnt, MemberTO_RM, House_TO_RM,ActionName)
	SELECT				
		bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup 			
		--, COUNT (DISTINCT bk.matchid) AS match_cnt			
		, COUNT(DISTINCT bk.transid) AS Bet_cnt			
		, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM		
		, 'Refund Match' as ActionName		
	FROM #temp_missing ms with (nolock)	
		cross apply (select matchid, transid, stake, actualrate, tpositiontaking,currency,statusID,winlostdate
					from bettrans_bk  WITH(NOLOCK) 
					where matchid = @matchid AND currency <> 20 
						AND statusID = 103
						and winlostdate = @wld
					--UNION ALL
					--select matchid, transid, stake, actualrate, tpositiontaking,currency, statusID, winlostdate
					--from bodb02.dbo.bettrans  WITH(NOLOCK) 
					--where matchid = ms.matchid
					--	AND currency <> 20 
					--	AND statusID = 103 
					) AS bk
								
		--INNER JOIN bettrans_bk bk WITH(NOLOCK) ON bk.matchid = ms.matchid	AND bk.currency <> 20 AND bk.statusID = 103	
	WHERE ms.matchid = @matchid

	GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup			
	ORDER BY winlostdate	

end

SELECT * FROM #result


drop table #match
drop table #temp_missing