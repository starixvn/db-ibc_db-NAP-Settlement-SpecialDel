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
SET @from = '2022-12-01'
SET @to = '2022-01-01'
CREATE TABLE #message_tmp (reason VARCHAR(50), matchID INT, Content_en varchar(max))	

/*Range archive*/
INSERT INTO #message_tmp (reason, matchID, Content_en )	
SELECT 
	CASE 
		WHEN  Content_en LIKE '%Due to wrong Away team name displayed%considered REFUNDED%'
		   OR Content_en LIKE '%Due to wrong Home team name displayed%considered REFUNDED%'
		   OR Content_en LIKE '%Due to wrong player name displayed%considered REFUNDED%'
		   OR Content_en LIKE '%wrong team name displayed%are considered REFUNDED%'
		THEN 'Wrong Team Name'
		WHEN  Content_en LIKE '%Due to wrong league name displayed%considered REFUNDED%' 
		THEN 'Wrong League Name'
		WHEN Content_en LIKE '%Due to technical error%all bets taken are REFUNDED%' 
			 OR Content_en LIKE '%due to technical issue%considered REFUNDED%'
			 OR Content_en LIKE '%Due to technical error%considered REFUNDED%' THEN 'Technical Error'
		WHEN Content_en LIKE '%Due to wrong market offered%considered REFUNDED%' 
			OR Content_en LIKE '%Due to wrong market offered%all bets taken are REFUNDED%' 
		THEN 'Wrong Market'
		WHEN Content_en LIKE '%Due to%Player%did not participate%considered REFUNDED%'THEN 'Not Participate' 
        WHEN Content_en LIKE '%The match between%abandoned%REFUNDED%'THEN 'Abandoned' 
        WHEN Content_en LIKE '%Due to wrong fixture displayed%considered REFUNDED%' THEN 'Wrong Fixture'
		ELSE 'Others' END as Reason
	,ms.matchid
	,ms.Content_en
FROM DBMSG.bodb_Message_Archive.dbo.[Msg_Archive] ms WITH (NOLOCK)  
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to
	AND (
		Content_en LIKE '%Due to wrong league name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong Away team name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong Home team name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong player name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong fixture displayed%considered REFUNDED%'
		OR Content_en LIKE '%wrong team name displayed%are considered REFUNDED%'
		OR Content_en LIKE '%Due to technical error%all bets taken are REFUNDED%'
		OR Content_en LIKE '%due to technical issue caused by disruption%are considered REFUNDED%'
		OR Content_en LIKE '%Due to technical error%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong market offered%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong market offered%all bets taken are REFUNDED%' 
        OR Content_en LIKE '%Due to%Player%did not participate%considered REFUNDED%'
        OR Content_en LIKE '%The match between%abandoned%REFUNDED%'
		)
	AND ms.MatchId > 0
	AND ms.IsTest = 0

/*Range active*/
INSERT INTO #message_tmp (reason, matchID, Content_en )	
SELECT 
	CASE 
		WHEN  Content_en LIKE '%Due to wrong Away team name displayed%considered REFUNDED%'
		   OR Content_en LIKE '%Due to wrong Home team name displayed%considered REFUNDED%'
		   OR Content_en LIKE '%Due to wrong player name displayed%considered REFUNDED%'
		   OR Content_en LIKE '%wrong team name displayed%are considered REFUNDED%'
		THEN 'Wrong Team Name'
		WHEN  Content_en LIKE '%Due to wrong league name displayed%considered REFUNDED%' 
		THEN 'Wrong League Name'
		WHEN Content_en LIKE '%Due to technical error%all bets taken are REFUNDED%' 
			 OR Content_en LIKE '%due to technical issue%considered REFUNDED%'
			 OR Content_en LIKE '%Due to technical error%considered REFUNDED%' THEN 'Technical Error'
		WHEN Content_en LIKE '%Due to wrong market offered%considered REFUNDED%' 
			 OR Content_en LIKE '%Due to wrong market offered%all bets taken are REFUNDED%' 
		THEN 'Wrong Market'
		WHEN Content_en LIKE '%Due to%Player%did not participate%considered REFUNDED%'THEN 'Not Participate' 
        WHEN Content_en LIKE '%The match between%abandoned%REFUNDED%'THEN 'Abandoned' 
        WHEN Content_en LIKE '%Due to wrong fixture displayed%considered REFUNDED%' THEN 'Wrong Fixture'
		ELSE 'Others' END as Reason
	,ms.matchid
	,ms.Content_en
FROM DBMSG.bodb_Message.dbo.[Msg] ms WITH (NOLOCK) 
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to
	AND (
		Content_en LIKE '%Due to wrong league name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong Away team name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong Home team name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong player name displayed%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong fixture displayed%considered REFUNDED%'
		OR Content_en LIKE '%wrong team name displayed%are considered REFUNDED%'
		OR Content_en LIKE '%Due to technical error%all bets taken are REFUNDED%'
		OR Content_en LIKE '%due to technical issue%are considered REFUNDED%'
		OR Content_en LIKE '%Due to technical error%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong market offered%considered REFUNDED%'
		OR Content_en LIKE '%Due to wrong market offered%all bets taken are REFUNDED%' 
        OR Content_en LIKE '%Due to%Player%did not participate%considered REFUNDED%'
        OR Content_en LIKE '%The match between%abandoned%REFUNDED%'
		)
	AND ms.MatchId > 0
	AND ms.IsTest = 0

 --Step 2.2: With case matchID = 0 from table #message_tmp -> get matchID 
 /*
DECLARE @led VARCHAR(400)
	, @home VARCHAR(400)
	, @away VARCHAR(400)

select @led='SABA ELITE FRIENDLY Virtual PES 20 - 5 Mins Play',@home='Manchester City (V)',@away='Tottenham Hotspur (V)'

SELECT top 1000 m.matchid, eventstatus, m.eventdate, betstatus, leaguename, m.home, m.away
FROM bodb02.dbo.league l WITH (NOLOCK)
	cross apply (select top 1000 m.*, h.teamname as home, a.teamname as away
				from 
				match_bk m WITH (NOLOCK)
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
					and matchid = 40209121

				) as m
WHERE 
--l.leagueid in (78365) --,78366,78367)
--and year(m.eventdate) = 2018 
	l.leaguename LIKE '%' + @led + '%'	
	--AND
	
	--and m.eventdate = '2020-06-26'
order by m.eventdate desc
*/

--select * from bodb02.dbo.team with (nolock) where teamname like '%CHINA FOOTBALL SUPER LEAGUE - CORNERS%'
--select * from 	bodb02.dbo.league l WITH (NOLOCK) where l.leaguename LIKE  '%Beach Volleyball - FIVB Caspian Sea Series Bandar Anzali Tour Men%'


-- Step 2.3: Final Result: input matchid, reason from step 2.2

CREATE TABLE #match_pre (reason VARCHAR(50), matchid INT)
insert into #match_pre (reason, matchid)
select DISTINCT reason, matchid
from #message_tmp

create table #match (matchid  INT,reason varchar(50), eventdate datetime,isfinished BIT)
insert into #match (matchid, eventdate, reason)
select m.matchid, m.eventdate, mpr.reason 
from #match_pre mpr 
	cross apply (
		Select matchid, eventdate, homeid, awayid , leagueid
		from match_bk  (nolock) 
		where matchid = mpr.matchid
		
		union all
		Select matchid, eventdate, homeid, awayid , leagueid
		from bodb02.dbo.match14  (nolock) 
		where matchid = mpr.matchid
		
		union all
		Select matchid, eventdate, homeid, awayid , leagueid
		from bodb02.dbo.match  (nolock) 
		where matchid = mpr.matchid
	)m
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
				
		UNION ALL		
		SELECT  matchid, leagueid	, h.teamname as home, a.teamname as away	, s.SportName, m.sporttype	
		FROM	bodb02.dbo.match14 m WITH (NOLOCK)	
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid
			left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid 
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype	
		WHERE	matchid = d.matchid	
				
		UNION ALL		
		SELECT  matchid, leagueid , h.teamname as home, a.teamname as away, s.SportName, m.sporttype		
		FROM	bodb02.dbo.match m WITH (NOLOCK)	
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid
			left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid 	
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype
		WHERE	matchid = d.matchid	
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
					UNION ALL
					select matchid, transid, stake, actualrate, tpositiontaking,currency, statusID, winlostdate
					from bodb02.dbo.bettrans  WITH(NOLOCK) 
					where matchid = ms.matchid
						AND currency <> 20 
						AND statusID = 103 
										UNION ALL
					select matchid, transid, stake, actualrate, tpositiontaking,currency, statusID, winlostdate
					from bodb02.dbo.bettrans14  WITH(NOLOCK) 
					where matchid = ms.matchid
						AND currency <> 20 
						AND statusID = 103 
					) AS bk
								
	WHERE ms.matchid = @matchid

	GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup			
	ORDER BY winlostdate	

end

SELECT DISTINCT 'Yes' AS IsMonthly																									
	, 'SD'FunctionGroup, ms.winlostdate, ms.Reason, ms.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup										
    , ms.Bet_cnt																								
	, ms.MemberTO_RM, ms.House_TO_RM	
    , ms.ActionName
FROM #result ms

drop table #message_tmp
drop table #match
drop table #temp_missing
drop table #match_pre
drop table #result
