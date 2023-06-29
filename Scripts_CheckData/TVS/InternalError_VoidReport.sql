/*db061/bodb_archive*/
--drop table #message_tmp																									
																									
DECLARE @from datetime, @to datetime																									
SET @from = '2022-09-01'																									
SET @to = '2022-10-01'																									
																									
CREATE TABLE #message_tmp (messageID INT, reason VARCHAR(50), transid BIGINT)																									
/*Range archive*/																							
INSERT INTO #message_tmp (messageID, reason, transid)																									
SELECT   MessageId																									
	, CASE 
			WHEN Content_en LIKE '%Due to%bets erroneously accepted%danger play%'
				OR Content_en LIKE '%Due to%match has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%goal% has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%Booking% has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%corner% has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%the first penalty kick had been taken%considered VOID%'
				OR Content_en LIKE '%Due to a goal was scored from a penalty awarded from VAR review for the match between%considered VOID%'
				OR Content_en LIKE '%Due to an official decision to award%team%after reviewing VAR for the match between%considered VOID%'
				THEN 'Danger Accepted'
			WHEN Content_en LIKE '%Due to%wrong odds displayed%considered VOID%' 
				THEN 'Wrong Odds'
			WHEN Content_en LIKE '%Due to%wrong score displayed%considered VOID%' 
				OR Content_en LIKE '%Due to an official decision to award a goal after reviewing VAR for the match between%considered VOID%'
				OR Content_en LIKE '%Due to an official decision to cancel%team Booking after reviewing VAR for the match between%considered VOID%'
				OR Content_en LIKE '%Due to an official decision to cancel a goal after reviewing VAR for the match between%considered VOID%'
			THEN 'Wrong Score'
			WHEN Content_en LIKE '%Due to%wrong HDP displayed%considered VOID%' THEN 'Wrong HDP'
			WHEN Content_en LIKE '%Due to%wrong%HDP displayed%considered VOID%' THEN 'Wrong 1st HDP'
			WHEN Content_en LIKE '%Due to%wrong OU displayed%considered VOID%' 
				OR Content_en LIKE  '%Due to%wrong%Game Over/Under%'
				THEN 'Wrong OU'
			WHEN Content_en LIKE '%Due to%wrong%OU displayed%considered VOID%' THEN 'Wrong 1st OU'
			WHEN Content_en LIKE '%Due to%early kick off%considered VOID%'
				OR Content_en LIKE '%Due to%match early tip off%considered VOID%'
				OR Content_en LIKE '%Due to%event early%considered VOID%'
				THEN 'Early Kick Off'
			WHEN Content_en LIKE '%Due to%wrong%time displayed%considered VOID%' THEN 'Wrong Kick Off Time'
			WHEN Content_en LIKE '%Due to%wrong market offered caused by%considered VOID%'
				OR Content_en LIKE '%Due to%red card being awarded to%considered VOID%'
				OR Content_en LIKE '%Due to%wrong odds offered on replacement of%considered VOID%' 
				OR Content_en LIKE '%Due to an official decision to cancel%team%after reviewing VAR for the match between%considered VOID%'
				THEN 'Red card'
			WHEN Content_en LIKE '%Due to%wrong market offered on Live betting for match%considered VOID%' THEN 'Wrong Market Offered'
			WHEN Content_en LIKE '%Due to%Wicket%has been completed%considered VOID%' THEN 'Match Completed'
			WHEN Content_en LIKE '%wrong team name displayed%considered VOID%' 
				OR Content_en LIKE '%Due to%wrong Away team name displayed%considered VOID'
				OR Content_en LIKE '%Due to%wrong Home team name displayed%considered VOID'
				OR content_en LIKE '%Wrong%Team Name%'
				THEN 'Wrong Team Name'
			WHEN Content_en LIKE '%Due to%wrong market offered%considered VOID%' THEN 'Wrong Market'
			WHEN Content_en LIKE '%Due to % corner has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%wrong event start time displayed%considered VOID%'
				OR Content_en LIKE '%Due to%the number of scheduled overs being reduced%considered VOID%'
				OR Content_en LIKE '%Due to%match was abandoned before the scheduled overs%considered VOID%'
				OR Content_en LIKE '%Due to%1st Half has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%technical error%considered VOID%'
				OR Content_en LIKE '%Due to%technical issue caused by disruption%considered VOID%'
				OR Content_en LIKE '%Due to%Player%did not participate%considered VOID%'
                OR Content_en LIKE '%Due to%has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%number of rounds have changed%considered VOID%'
			THEN 'Other Issues'
			ELSE 'Other Issues'
		END as Reason																						
		, t.transid																							
from DBMSG.bodb_Message_Archive.dbo.[Msg_Archive] ms WITH (NOLOCK)
	CROSS APPLY (SELECT DISTINCT BetTransId																								
			FROM DBMSG.bodb_Message_Archive.[dbo].[MsgTarget_Archive] mt1 with (nolock)																						
			WHERE mt1.MessageId= ms.MessageId																						
				AND mt1.isDeleted = 0																					
				AND mt1.BettransId <> ''																					
			) mt	
	CROSS APPLY (select ltrim(rtrim(value)) as transid 
				from STRING_SPLIT(mt.BetTransId,',')
		) as t																								
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to																									
	AND (
		Content_en NOT LIKE '%Due to abnormal bets%considered VOID%' --Exclude Abnormal account, Abnormal bet
		)																	
	--AND ms.MatchId > 0																								
	AND ms.IsTest = 0	
	

/*Range active*/																							
INSERT INTO #message_tmp (messageID, reason, transid)																									
SELECT   MessageId																									
	, CASE 
			WHEN Content_en LIKE '%Due to%bets erroneously accepted%danger play%'
				OR Content_en LIKE '%Due to%match has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%goal% has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%Booking% has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%corner% has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%the first penalty kick had been taken%considered VOID%'
				OR Content_en LIKE '%Due to a goal was scored from a penalty awarded from VAR review for the match between%considered VOID%'
				OR Content_en LIKE '%Due to an official decision to award%team%after reviewing VAR for the match between%considered VOID%'
				THEN 'Danger Accepted'
			WHEN Content_en LIKE '%Due to%wrong odds displayed%considered VOID%' 
				THEN 'Wrong Odds'
			WHEN Content_en LIKE '%Due to%wrong score displayed%considered VOID%' 
				OR Content_en LIKE '%Due to an official decision to award a goal after reviewing VAR for the match between%considered VOID%'
				OR Content_en LIKE '%Due to an official decision to cancel%team Booking after reviewing VAR for the match between%considered VOID%'
				OR Content_en LIKE '%Due to an official decision to cancel a goal after reviewing VAR for the match between%considered VOID%'
			THEN 'Wrong Score'
			WHEN Content_en LIKE '%Due to%wrong HDP displayed%considered VOID%' THEN 'Wrong HDP'
			WHEN Content_en LIKE '%Due to%wrong%HDP displayed%considered VOID%' THEN 'Wrong 1st HDP'
			WHEN Content_en LIKE '%Due to%wrong OU displayed%considered VOID%' 
				OR Content_en LIKE  '%Due to%wrong%Game Over/Under%'
				THEN 'Wrong OU'
			WHEN Content_en LIKE '%Due to%wrong%OU displayed%considered VOID%' THEN 'Wrong 1st OU'
			WHEN Content_en LIKE '%Due to%early kick off%considered VOID%'
				OR Content_en LIKE '%Due to%match early tip off%considered VOID%'
				OR Content_en LIKE '%Due to%event early%considered VOID%'
				THEN 'Early Kick Off'
			WHEN Content_en LIKE '%Due to%wrong%time displayed%considered VOID%' THEN 'Wrong Kick Off Time'
			WHEN Content_en LIKE '%Due to%wrong market offered caused by%considered VOID%'
				OR Content_en LIKE '%Due to%red card being awarded to%considered VOID%'
				OR Content_en LIKE '%Due to%wrong odds offered on replacement of%considered VOID%' 
				OR Content_en LIKE '%Due to an official decision to cancel%team%after reviewing VAR for the match between%considered VOID%'
				THEN 'Red card'
			WHEN Content_en LIKE '%Due to%wrong market offered on Live betting for match%considered VOID%' THEN 'Wrong Market Offered'
			WHEN Content_en LIKE '%Due to%Wicket%has been completed%considered VOID%' THEN 'Match Completed'
			WHEN Content_en LIKE '%wrong team name displayed%considered VOID%' 
				OR Content_en LIKE '%Due to%wrong Away team name displayed%considered VOID'
				OR Content_en LIKE '%Due to%wrong Home team name displayed%considered VOID'
				OR content_en LIKE '%Wrong%Team Name%'
				THEN 'Wrong Team Name'
			WHEN Content_en LIKE '%Due to%wrong market offered%considered VOID%' THEN 'Wrong Market'
			WHEN Content_en LIKE '%Due to % corner has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%wrong event start time displayed%considered VOID%'
				OR Content_en LIKE '%Due to%the number of scheduled overs being reduced%considered VOID%'
				OR Content_en LIKE '%Due to%match was abandoned before the scheduled overs%considered VOID%'
				OR Content_en LIKE '%Due to%1st Half has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%technical error%considered VOID%'
				OR Content_en LIKE '%Due to%technical issue caused by disruption%considered VOID%'
				OR Content_en LIKE '%Due to%Player%did not participate%considered VOID%'
                OR Content_en LIKE '%Due to%has been completed%considered VOID%'
				OR Content_en LIKE '%Due to%number of rounds have changed%considered VOID%'
			THEN 'Other Issues'
			ELSE 'Other Issues'
		END as Reason																						
		, t.transid																							
FROM DBMSG.bodb_Message.dbo.[Msg] ms WITH (NOLOCK)	
	CROSS APPLY (SELECT DISTINCT BetTransId																								
			FROM DBMSG.bodb_Message.[dbo].[MsgTarget] mt1 with (nolock)																						
			WHERE mt1.MessageId= ms.MessageId																						
				AND mt1.isDeleted = 0																					
				AND mt1.BettransId <> ''																					
			) mt
	CROSS APPLY (select ltrim(rtrim(value)) as transid 
				from STRING_SPLIT(mt.BetTransId,',')
		) as t																								
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to																									
	AND (
		Content_en NOT LIKE '%Due to abnormal bets%considered VOID%' --Exclude Abnormal account, Abnormal bet
		)																	
	AND ms.IsTest = 0																								
																										
CREATE TABLE #temp_transid (transid bigint,reason varchar(50), matchid INT,sporttype tinyint, sportName nVARCHAR(100), home nvarchar(200), away varchar(200), leaguename varchar(1000), LeagueGroup varchar(200))																									

/*Range archive*/
INSERT INTO #temp_transid (transid,reason,matchid)	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid												
FROM #message_tmp ms with (nolock)																									
	INNER JOIN bodb_archive.dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	
WHERE d.matchid	<> 29

/*Range active*/
INSERT INTO #temp_transid (transid,reason,matchid)	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid												
FROM #message_tmp ms with (nolock)																									
	INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.transid = ms.TransId	
WHERE d.matchid	<> 29

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
WHERE bk.winlostdate >= @from AND bk.winlostdate < @to																						
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
WHERE bk.winlostdate >= @from AND bk.winlostdate < @to
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
WHERE bk.winlostdate >= @from AND bk.winlostdate < @to	
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																									
ORDER BY winlostdate																									

DROP TABLE #message_tmp
DROP TABLE #temp_transid


