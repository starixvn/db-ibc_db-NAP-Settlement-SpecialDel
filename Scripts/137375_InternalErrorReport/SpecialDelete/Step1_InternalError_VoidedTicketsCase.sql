/*db061/bodb_archive*/
--drop table #message_tmp																									
																									
DECLARE @from datetime, @to datetime																									
SET @from = '2018-12-01'																									
SET @to = '2019-01-01'																									
																									
CREATE TABLE #message_tmp (messageID INT, reason VARCHAR(50), transid BIGINT)																									
																									
INSERT INTO #message_tmp (messageID, reason, transid)																									
SELECT   MessageId																									
	, CASE 
			WHEN Content_en LIKE '%Due to wrong score displayed%' THEN 'wrong score'
			WHEN Content_en LIKE '%Due to wrong odds displayed%' THEN 'wrong odds'
			WHEN Content_en LIKE '%Due to wrong%OU displayed%' 
				OR Content_en LIKE  '%Due to wrong%Game Over/Under%' THEN 'wrong OU'
			WHEN Content_en LIKE '%Due to wrong%HDP displayed%' THEN 'wrong HPD'
			WHEN Content_en LIKE '%Due to bets erroneously accepted%danger play%' THEN 'Danger Accept'
			WHEN Content_en LIKE '%wrong team name displayed%considered VOID%' 
				OR Content_en LIKE '%Due to wrong Away team name displayed%considered VOID'
				OR Content_en LIKE '%Due to wrong Home team name displayed%considered VOID'
				OR content_en LIKE '%Wrong%Team Name%'
		THEN 'Wrong Team Name'
			WHEN Content_en LIKE '%Due to wrong market offered%considered VOID%' THEN 'Wrong Market'
			WHEN Content_en LIKE '%Due to 1st corner has been completed%' THEN 'Others'
		END as Reason																						
		, t.transid																							
from Db05bk1.bodb_Message_Archive.dbo.[Msg_Archive] ms WITH (NOLOCK)
	CROSS APPLY (SELECT DISTINCT BetTransId																								
			FROM Db05bk1.bodb_Message_Archive.[dbo].[MsgTarget_Archive] mt1 with (nolock)																						
			WHERE mt1.MessageId= ms.MessageId																						
				AND mt1.isDeleted = 0																					
				AND mt1.BettransId <> ''																					
			) mt	
	--Db05bk1.bodb_Message.dbo.[Msg] ms WITH (NOLOCK)	
	--CROSS APPLY (SELECT DISTINCT BetTransId																								
	--		FROM Db05bk1.bodb_Message.[dbo].[MsgTarget] mt1 with (nolock)																						
	--		WHERE mt1.MessageId= ms.MessageId																						
	--			AND mt1.isDeleted = 0																					
	--			AND mt1.BettransId <> ''																					
	--		) mt
																										
	CROSS APPLY (select ltrim(rtrim(val)) as transid from bodb02.[dbo].f_SplitString (mt.BetTransId,',')
				
		) as t																								
																									
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to																									
	AND (
		-- #1 wrong score
		Content_en LIKE '%Due to wrong score displayed%'
		---- #2 wrong odds
		OR Content_en LIKE '%Due to wrong odds displayed%'
		-- #3 wrong OU
		OR Content_en LIKE '%Due to wrong%OU displayed%' 
		OR Content_en LIKE  '%Due to wrong%Game Over/Under%'
		-- #4 wrong HDP
		OR Content_en LIKE '%Due to wrong%HDP displayed%'
		-- #5 Danger Accept
		OR Content_en LIKE '%Due to bets erroneously accepted%danger play%'
		-- #6 Wrong Team name
		OR Content_en LIKE '%wrong team name displayed%considered VOID%'
		OR Content_en LIKE '%Due to wrong Away team name displayed%considered VOID'
		OR Content_en LIKE '%Due to wrong Home team name displayed%considered VOID'
		OR content_en LIKE  '%Wrong%Team Name%'
		-- #7 Wrong market
		OR Content_en LIKE '%Due to wrong market offered%considered VOID%'
		-- #8 Others
		OR Content_en LIKE  '%Due to 1st corner has been completed%' 
		)																	
	--AND ms.MatchId > 0																								
	AND ms.IsTest = 0																								
OPTION (maxrecursion 0)
																									
CREATE TABLE #temp_transid (transid bigint,reason varchar(50), matchid INT,sporttype tinyint, sportName nVARCHAR(100), home nvarchar(200), away varchar(200), leaguename varchar(1000), LeagueGroup varchar(200))																									
INSERT INTO #temp_transid (transid,reason,matchid,sporttype, sportName, home, away, leaguename, LeagueGroup)																									
SELECT DISTINCT ms.TransId, ms.reason, d.matchid,m.sporttype, m.SportName, m.home, m.away, l.leaguename,case when isnull(l.[Group],'')=''  then 'Others' else l.[Group] end LeagueGroup																									
FROM #message_tmp ms with (nolock)																									
	INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.transid = ms.TransId																								
	CROSS APPLY (																								
		SELECT	matchid, leagueid, h.teamname as home, a.teamname as away, s.SportName, m.sporttype																						
		FROM	dbo.match_bk m WITH (NOLOCK)																						
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
			left join bodb02.dbo.team a with (nolock) on a.teamid = m.homeid																						
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
																									
		WHERE	matchid = d.matchid																						
																									
		--UNION ALL																							
		--SELECT  matchid, leagueid	, h.teamname as home, a.teamname as away	, s.SportName, m.sporttype																					
		--FROM	bodb02.dbo.match14 m WITH (NOLOCK)																						
		--	left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
		--	left join bodb02.dbo.team a with (nolock) on a.teamid = m.homeid																						
		--	left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		--WHERE	matchid = d.matchid																						
																									
		--UNION ALL																							
		--SELECT  matchid, leagueid , h.teamname as home, a.teamname as away, s.SportName, m.sporttype																							
		--FROM	bodb02.dbo.match m WITH (NOLOCK)																						
		--	left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
		--	left join bodb02.dbo.team a with (nolock) on a.teamid = m.homeid																						
		--	left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		--WHERE	matchid = d.matchid																						
	) m																								
	INNER JOIN bodb02.dbo.League l WITH (NOLOCK)																								
		ON m.leagueid = l.leagueid																							
WHERE l.isTest = 0																									
																									
SELECT																									
	bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																								
	--, COUNT (DISTINCT bk.matchid) AS match_cnt																								
	, COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, 'VOID' AS ActionName																							 
FROM #temp_transid ms with (nolock)																									
	INNER JOIN bettrans_bk bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102																								
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																									
ORDER BY winlostdate																									

DROP TABLE #message_tmp
DROP TABLE #temp_transid


--select * from match_bk (nolock)	where matchid = 7389676