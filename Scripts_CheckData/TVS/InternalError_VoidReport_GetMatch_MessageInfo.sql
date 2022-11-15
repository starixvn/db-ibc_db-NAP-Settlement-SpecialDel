/*db061/bodb_archive*/
/*Example 1: 
MatchID 58089493 Attn:[Soccer] Due to bets erroneously accepted in away red card danger play during the match between "Reims -vs- Paris Saint Germain" [FRANCE LIGUE 1 - 8/10*Live*], bet ID: "@@" placed from 9/10 3:41:00 AM - 3:41:06 AM (GMT+8) (Score 0-0) which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. Sorry for the inconvenience caused!  
*/
/*
Example 2: 
Date: 2 Aug 2022 
Sport type: E-Sports 
League: League of Legends - Streamer 
Match: bobqinxd -vs- Rush 
Status: Wrong Team Name 
*/
	
--	Step 1: Get matchid	
/*
select * from bodb02.dbo.team with (nolock) where teamname like '%bobqinxd%' OR teamname like '%Rush%'
select * from 	bodb02.dbo.league l WITH (NOLOCK) where l.leaguename LIKE  '%League of Legends - Streamer%'

*/

CREATE TABLE #temp_transid (transid bigint,reason varchar(50), matchid INT,sporttype tinyint, sportName nVARCHAR(100), home nvarchar(200), away varchar(200), leaguename varchar(1000), LeagueGroup varchar(200))																									

DECLARE @matchID INT = XXX
/*Range archive*/
INSERT INTO #temp_transid (transid,reason,matchid)	
SELECT DISTINCT d.TransId
, 'Other Issues' -- OR Status(ex2) as reason
, d.matchid												
FROM bodb_archive.dbo.zzzbettrans_bk d WITH (NOLOCK)
WHERE d.matchid = @matchID

/*Range active*/
INSERT INTO #temp_transid (transid,reason,matchid)	
SELECT DISTINCT d.TransId
, 'Other Issues' -- OR Status(ex2) as reason
, d.matchid											
FROM bodb02.dbo.zzzbettrans d WITH (NOLOCK) 
WHERE d.matchid = @matchID

UPDATE d
SET d.sporttype =   m.sporttype
, d.sportName = m.SportName
, d.home = m.home
, d.away = m.away
, d.leaguename = l.leaguename
, d.LeagueGroup = case when isnull(l.[Group],'')=''  then 'Others' else l.[Group] end																					
FROM #temp_transid d
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
		
		UNION ALL																							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	bodb02.dbo.outright m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.teamid																						
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid		
	) m																								
	INNER JOIN bodb02.dbo.League l WITH (NOLOCK)																								
		ON m.leagueid = l.leagueid																							
WHERE l.isTest = 0																
																									
SELECT																									
	bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																								
	, COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, 'VOID' AS ActionName																							 
FROM #temp_transid ms with (nolock)																									
	INNER JOIN bettrans_bk bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																									
ORDER BY winlostdate

SELECT																									
	bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																								
	, COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, 'VOID' AS ActionName																							 
FROM #temp_transid ms with (nolock)																									
	INNER JOIN bodb02.dbo.bettrans14 bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																									
ORDER BY winlostdate	

SELECT																									
	bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																								
	, COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, 'VOID' AS ActionName																							 
FROM #temp_transid ms with (nolock)																									
	INNER JOIN bodb02.dbo.bettrans bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102		
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																									
ORDER BY winlostdate																									

DROP TABLE #temp_transid


