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
SET @from = '2020-06-01'
SET @to = '2020-06-30'

SELECT 
	CASE 
		WHEN Content_en LIKE '%Due to wrong fixture displayed%considered REFUNDED%' THEN 'Others'
		WHEN  Content_en LIKE '%Due to wrong league name displayed%considered REFUNDED%' THEN 'wrong league name'
		ELSE 'wrong team name' END as Reason
	,ms.matchid
	,ms.Content_en
from 
--Db05bk1.bodb_Message_Archive.dbo.[Msg_Archive] ms WITH (NOLOCK)  
Db05bk1.bodb_Message.dbo.[Msg] ms WITH (NOLOCK) 
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
DECLARE @leagueName VARCHAR(400)
	, @home VARCHAR(400)
	, @away VARCHAR(400)

SELECT @leagueName = 'CLUB FRIENDLY- 25'		
	, @home = 'fastPay Wildcats Academy'
	, @away = 'Galakticos Academy'

SELECT top 10 m.matchid, eventstatus, m.eventdate, betstatus, leaguename
FROM 
	match_bk m WITH (NOLOCK)
	--bodb02.dbo.match m WITH (NOLOCK)
	--bodb02.dbo.match14 m WITH (NOLOCK)
	INNER JOIN bodb02.dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
	INNER JOIN bodb02.dbo.team h WITH (NOLOCK) ON h.teamid = m.homeid
	INNER JOIN bodb02.dbo.team a WITH (NOLOCK) ON a.teamid = m.awayid
WHERE 
--l.leaguename LIKE '%' + @leagueName + '%'	
	--AND
	 h.teamname LIKE '%' + @home + '%'
	AND a.teamname LIKE '%' + @away + '%'
	and m.eventdate = '2020-06-26'

--select * from bodb02.dbo.team with (nolock) where teamname like '%Raufoss IL%'
--select * from 	bodb02.dbo.league l WITH (NOLOCK) where l.leaguename LIKE '%CLUB FRIENDLY%'	
*/
-- Final result
--- missing refund match
/*

matchid		eventstatus	eventdate				betstatus		leaguename
36884064	Completed	2020-06-25 00:00:00.000	Refund;			CLUB FRIENDLY
36813706	completed	2020-06-26 00:00:00.000	Refund;			League of Legends - Turkey Academy League Summer
*/

-- Step 2.3: Final Result: run one by one matchid for each reason
create table #match (matchid  INT, eventdate datetime,isfinished BIT)
insert into #match (matchid, eventdate)
select m.matchid, m.eventdate 
from match_bk m (nolock)
	inner join bodb02.dbo.Team h with (nolock) on h.teamid = m.homeid
	inner join bodb02.dbo.Team a with (nolock) on a.teamid = m.awayid
	INNER JOIN bodb02.dbo.League l (nolock) on l.leagueid = m.leagueid
where matchid in (36884064,36813706)
order by eventdate
	
CREATE TABLE #temp_missing (reason varchar(50), matchid INT,sporttype tinyint, sportName nVARCHAR(100), home nvarchar(200), away varchar(200), leaguename varchar(1000), LeagueGroup varchar(200))				

INSERT INTO #temp_missing (matchid,reason, sporttype, sportName, home, away, leaguename, LeagueGroup)				
SELECT DISTINCT d.matchid, 'wrong team name' reason, m.sporttype, m.SportName, m.home, m.away, l.leaguename,case when isnull(l.[Group],'')=''  then 'Others' else l.[Group] end LeagueGroup 				
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
	
	SELECT				
		bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup 			
		--, COUNT (DISTINCT bk.matchid) AS match_cnt			
		, COUNT(DISTINCT bk.transid) AS Bet_cnt			
		, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM		
		, 'Refund Match' as ActionName		
	FROM #temp_missing ms with (nolock)	
		cross apply (select matchid, transid, stake, actualrate, tpositiontaking,currency,statusID,winlostdate
					from bettrans_bk  WITH(NOLOCK) 
					where matchid = ms.matchid AND currency <> 20 
						AND statusID = 103
					UNION ALL
					select matchid, transid, stake, actualrate, tpositiontaking,currency, statusID, winlostdate
					from bodb02.dbo.bettrans  WITH(NOLOCK) 
					where matchid = ms.matchid
						AND currency <> 20 
						AND statusID = 103 
					) AS bk
								
		--INNER JOIN bettrans_bk bk WITH(NOLOCK) ON bk.matchid = ms.matchid	AND bk.currency <> 20 AND bk.statusID = 103	
	WHERE winlostdate = @wld AND ms.matchid = @matchid

	GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup			
	ORDER BY winlostdate	

end

drop table #match
drop table #temp_missing

