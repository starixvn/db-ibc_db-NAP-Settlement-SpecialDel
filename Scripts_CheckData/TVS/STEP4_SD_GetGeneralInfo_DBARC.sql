/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/
USE bodb_archive 
GO

DECLARE @from datetime, @to datetime																						
SET @from = '2023-09-01'																									
SET @to = '2023-10-01'																									
																									
CREATE TABLE #message_tmp (messageID INT, reason VARCHAR(50), transid BIGINT, MessageContent varchar(max))																								
CREATE TABLE #temp_transid (
transid bigint
,reason varchar(50)
, matchid INT
, sporttype tinyint
, sportName nVARCHAR(100)
, home nvarchar(200)
, away varchar(200)
, leaguename varchar(1000)
, LeagueGroup varchar(200)
, MessageContent varchar(max)

)

/*Range archive*/																							
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent)																									
SELECT   MessageId																									
		, CASE 
			WHEN Content_en LIKE '%Due to%bets erroneously accepted%danger play%'
			  OR Content_en LIKE '%Due to%match has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%goal% has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%Booking% has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%corner% has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%the first penalty kick had been taken%considered VOID%'
			  OR Content_en LIKE '%Due to%a goal was scored from a penalty awarded%%considered VOID%'
			  OR Content_en LIKE '%Due to%an official decision to award%considered VOID%'
			  OR Content_en LIKE '%Due to%1st Half has been completed%considered VOID%'
			THEN 'Danger Accepted'
			WHEN Content_en LIKE '%Due to%wrong odds displayed%considered VOID%' THEN 'Wrong Odds'
			WHEN Content_en LIKE '%Due to%wrong score displayed%considered VOID%' 
			  OR Content_en LIKE '%Due to%an official decision to cancel%considered VOID%'
			THEN 'Wrong Score'
			WHEN Content_en LIKE '%Due to%wrong HDP displayed%considered VOID%' THEN 'Wrong HDP'
			WHEN Content_en LIKE '%Due to%wrong%HDP displayed%considered VOID%' THEN 'Wrong 1st HDP'
			WHEN Content_en LIKE '%Due to%wrong OU displayed%considered VOID%' THEN 'Wrong OU'
			WHEN Content_en LIKE '%Due to%wrong%OU displayed%considered VOID%' THEN 'Wrong 1st OU'
			WHEN Content_en LIKE '%Due to%early%considered VOID%' THEN 'Early Kick Off'
			WHEN Content_en LIKE '%Due to%wrong%time displayed%considered VOID%' THEN 'Wrong Kick Off Time'
			WHEN Content_en LIKE '%Due to%wrong market offered caused by%considered VOID%'
				OR Content_en LIKE '%Due to%red card being awarded to%considered VOID%'
				OR Content_en LIKE '%Due to%wrong odds offered on replacement of%considered VOID%' 
				OR Content_en LIKE '%Due to%an official decision to cancel%team%after reviewing VAR for the match between%considered VOID%'
				THEN 'Red card'
			WHEN Content_en LIKE '%Due to%abandoned%considered VOID%' THEN 'Abandoned'
			WHEN Content_en LIKE '%Due to%scheduled overs being reduced%considered VOID%' THEN 'Reduced Over'
			WHEN Content_en LIKE '%Due to%Player%did not participate%considered VOID%' THEN 'Not Participate'
			
			
			WHEN Content_en LIKE '%Due to%wrong market offered%match%considered VOID%' THEN 'Wrong Market Offered'
			WHEN Content_en LIKE '%Due to%Wicket%has been completed%considered VOID%' THEN 'Match Completed'
			WHEN Content_en LIKE '%Due to%wrong%team name displayed%considered VOID'THEN 'Wrong Team Name'
			WHEN Content_en LIKE '%Due to%technical error%VOID%' THEN 'Technical Error'
			WHEN Content_en LIKE '%Due to%technical issue caused by disruption%considered VOID%' THEN 'Game Crashed Void Live' -- Subtype
			WHEN Content_en LIKE '%Due to%abnormal bets%VOID%' THEN 'Abnormal Bet'
			ELSE 'Other Issues'
		END as Reason																						
		, t.transid		
		, ms.Content_en
FROM DBMSG.bodb_Message_Archive.dbo.[Msg_Archive] ms WITH (NOLOCK)
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
	AND ms.IsTest = 0	
	AND Content_en LIKE '%Due to%VOID%'

/*Range active*/																							
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent)																									
SELECT   MessageId																									
	, CASE 
			WHEN Content_en LIKE '%Due to%bets erroneously accepted%danger play%'
			  OR Content_en LIKE '%Due to%match has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%goal% has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%Booking% has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%corner% has been completed%considered VOID%'
			  OR Content_en LIKE '%Due to%the first penalty kick had been taken%considered VOID%'
			  OR Content_en LIKE '%Due to%a goal was scored from a penalty awarded%%considered VOID%'
			  OR Content_en LIKE '%Due to%an official decision to award%considered VOID%'
			  OR Content_en LIKE '%Due to%1st Half has been completed%considered VOID%' THEN 'Danger Accepted'
			WHEN Content_en LIKE '%Due to%wrong odds displayed%considered VOID%' THEN 'Wrong Odds'
			WHEN Content_en LIKE '%Due to%wrong score displayed%considered VOID%' 
			  OR Content_en LIKE '%Due to%an official decision to cancel%considered VOID%' THEN 'Wrong Score'
			WHEN Content_en LIKE '%Due to%wrong HDP displayed%considered VOID%' THEN 'Wrong HDP'
			WHEN Content_en LIKE '%Due to%wrong%HDP displayed%considered VOID%' THEN 'Wrong 1st HDP'
			WHEN Content_en LIKE '%Due to%wrong OU displayed%considered VOID%' THEN 'Wrong OU'
			WHEN Content_en LIKE '%Due to%wrong%OU displayed%considered VOID%' THEN 'Wrong 1st OU'
			WHEN Content_en LIKE '%Due to%early%considered VOID%' THEN 'Early Kick Off'
			WHEN Content_en LIKE '%Due to%wrong%time displayed%considered VOID%' THEN 'Wrong Kick Off Time'
			WHEN Content_en LIKE '%Due to%wrong market offered caused by%considered VOID%'
			  OR Content_en LIKE '%Due to%red card being awarded to%considered VOID%'
			  OR Content_en LIKE '%Due to%wrong odds offered on replacement of%considered VOID%' 
			  OR Content_en LIKE '%Due to%an official decision to cancel%team%after reviewing VAR for the match between%considered VOID%' THEN 'Red card'
			WHEN Content_en LIKE '%Due to%abandoned%considered VOID%' THEN 'Abandoned'
			WHEN Content_en LIKE '%Due to%scheduled overs being reduced%considered VOID%' THEN 'Reduced Over'
			WHEN Content_en LIKE '%Due to%Player%did not participate%considered VOID%' THEN 'Not Participate'
			
			WHEN Content_en LIKE '%Due to%wrong market offered%match%considered VOID%' THEN 'Wrong Market Offered'
			WHEN Content_en LIKE '%Due to%Wicket%has been completed%considered VOID%' THEN 'Match Completed'
			WHEN Content_en LIKE '%Due to%wrong%team name displayed%considered VOID'THEN 'Wrong Team Name'
			WHEN Content_en LIKE '%Due to%technical error%VOID%' THEN 'Technical Error'
			WHEN Content_en LIKE '%Due to%technical issue caused by disruption%considered VOID%' THEN 'Game Crashed Void Live' -- Subtype
			WHEN Content_en LIKE '%Due to%abnormal bets%VOID%' THEN 'Abnormal Bet'
			ELSE 'Other Issues'
		END as Reason						
		, t.transid	
		, ms.Content_en
FROM DBMSG.bodb_Message.dbo.[Msg] ms WITH (NOLOCK)	
	CROSS APPLY (SELECT DISTINCT BetTransId																								
			FROM DBMSG.bodb_Message.[dbo].[MsgTarget] mt1 WITH (NOLOCK)																						
			WHERE mt1.MessageId= ms.MessageId																						
				AND mt1.isDeleted = 0																					
				AND mt1.BettransId <> ''																					
			) mt
	CROSS APPLY (select ltrim(rtrim(value)) as transid 
				from STRING_SPLIT(mt.BetTransId,',')
		) as t																								
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to																									
	AND ms.IsTest = 0																								
	AND Content_en LIKE '%Due to%VOID%'	

/*Range archive*/
INSERT INTO #temp_transid (transid,reason,matchid, MessageContent)	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent											
FROM #message_tmp ms WITH (NOLOCK)																									
	INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	
WHERE d.VoidingHistoryId IS NULL

/*Range active*/
INSERT INTO #temp_transid (transid,reason,matchid, MessageContent)	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent												
FROM #message_tmp ms WITH (NOLOCK)																									
	INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.transid = ms.TransId	
WHERE d.VoidingHistoryId IS NULL

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
			LEFT JOIN bodb02.dbo.team h WITH (NOLOCK) on h.teamid = m.homeid																						
			LEFT JOIN bodb02.dbo.team a WITH (NOLOCK) on a.teamid = m.awayid																						
			LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = m.sporttype																						
		WHERE	matchid = d.matchid																						
																									
		UNION ALL																							
		SELECT  matchid, leagueid	, h.teamname as home, a.teamname as away	, s.SportName, m.sporttype																					
		FROM	bodb02.dbo.match14 m WITH (NOLOCK)																						
			LEFT JOIN bodb02.dbo.team h WITH (NOLOCK) on h.teamid = m.homeid																						
			LEFT JOIN bodb02.dbo.team a WITH (NOLOCK) on a.teamid = m.awayid																						
			LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = m.sporttype																						
		WHERE	matchid = d.matchid																						
																									
		UNION ALL																							
		SELECT  matchid, leagueid , h.teamname as home, a.teamname as away, s.SportName, m.sporttype																							
		FROM	bodb02.dbo.match m WITH (NOLOCK)																						
			LEFT JOIN bodb02.dbo.team h WITH (NOLOCK) on h.teamid = m.homeid																						
			LEFT JOIN bodb02.dbo.team a WITH (NOLOCK) on a.teamid = m.awayid																						
			LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = m.sporttype																						
		WHERE	matchid = d.matchid	
		
		UNION ALL																							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	bodb02.dbo.outright m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			LEFT JOIN bodb02.dbo.team h WITH (NOLOCK) on h.teamid = m.teamid																						
			LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid	
		
		UNION ALL																							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	bodb02.dbo.outright14 m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			LEFT JOIN bodb02.dbo.team h WITH (NOLOCK) on h.teamid = m.teamid																						
			LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid

		UNION ALL																							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	dbo.outright_bk m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			LEFT JOIN bodb02.dbo.team h WITH (NOLOCK) on h.teamid = m.teamid																						
			LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid
	) m																								
	INNER JOIN bodb02.dbo.League l WITH (NOLOCK)																								
		ON m.leagueid = l.leagueid																							
WHERE l.isTest = 0																
	
SELECT	DISTINCT CASE WHEN ms.Reason LIKE '%Abnormal Bet%' THEN 'No' ELSE 'Yes' END IsMonthly																											
	, 'SD' AS 'TVS/SD?', bk.winlostdate
	, YEAR(bk.winlostdate) AS YEAR_winlostdate
	, MONTH(bk.winlostdate) AS MONTH_winlostdate
	, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																		
    , COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
    , 'VOID' AS ActionName
	, '' as Function_SDName
	, '' AS RequestId, '' TotalTicket, '' TotalTicket_Parlay, '' Bet_cnt_Parlay
    , '' IssueType, '' SubIssueType
	, '' AS CreatedBy, '' CreatedDate,'' AS Duration, '' FromTimeUI, '' ToTimeUI
	, '' MistakenBy, '' DecidedBy,'' AS PerformanceBy
	,  'Manual Void' AS 'Auto Void?'
    , '' Min_Trans , '' Max_Trans , '' Min_TransDate , '' Max_TransDate , '' Liveindicator
	, '' AS ListBettypes, '' AS ListBetteams, '' ListScore,'' Calc_HTTime,'' Calc_FTTime
	,  ms.MessageContent
	, CASE WHEN MAX(CASE WHEN bk.statusID IN (111,112,113) THEN 1 ELSE 0 END) = 1 THEN 'Yes' ELSE 'No' END AS 'Has Void Settled?'
FROM #temp_transid ms WITH (NOLOCK)																									
	INNER JOIN bettrans_bk bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102	
	AND bk.winlostdate between  @from AND @to
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup, ms.MessageContent																							
ORDER BY winlostdate

SELECT	DISTINCT CASE WHEN ms.Reason LIKE '%Abnormal Bet%' THEN 'No' ELSE 'Yes' END IsMonthly																									
	, 'SD' AS 'TVS/SD?', bk.winlostdate
	, YEAR(bk.winlostdate) AS YEAR_winlostdate
	, MONTH(bk.winlostdate) AS MONTH_winlostdate
	, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																		
    , COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
    , 'VOID' AS ActionName
	, '' as Function_SDName
	, '' AS RequestId, '' TotalTicket, '' TotalTicket_Parlay, '' Bet_cnt_Parlay
    , '' IssueType, '' SubIssueType
	, '' AS CreatedBy, '' CreatedDate,'' AS Duration, '' FromTimeUI, '' ToTimeUI
	, '' MistakenBy, '' DecidedBy,'' AS PerformanceBy
	,  'Manual Void' AS 'Auto Void?'
    , '' Min_Trans , '' Max_Trans , '' Min_TransDate , '' Max_TransDate , '' Liveindicator
	, '' AS ListBettypes, '' AS ListBetteams, '' ListScore,'' Calc_HTTime,'' Calc_FTTime
	,  ms.MessageContent
	, CASE WHEN MAX(CASE WHEN bk.statusID IN (111,112,113) THEN 1 ELSE 0 END) = 1 THEN 'Yes' ELSE 'No' END AS 'Has Void Settled?'
FROM #temp_transid ms WITH (NOLOCK)																									
	INNER JOIN bodb02.dbo.bettrans14 bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102
	AND bk.winlostdate between  @from AND @to
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup, ms.MessageContent																							
ORDER BY winlostdate	


SELECT	DISTINCT CASE WHEN ms.Reason LIKE '%Abnormal Bet%' THEN 'No' ELSE 'Yes' END IsMonthly																								
	, 'SD' AS 'TVS/SD?', bk.winlostdate
	, YEAR(bk.winlostdate) AS YEAR_winlostdate
	, MONTH(bk.winlostdate) AS MONTH_winlostdate
	, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																		
    , COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
    , 'VOID' AS ActionName
	, '' as Function_SDName
	, '' AS RequestId, '' TotalTicket, '' TotalTicket_Parlay, '' Bet_cnt_Parlay
    , '' IssueType, '' SubIssueType
	, '' AS CreatedBy, '' CreatedDate,'' AS Duration, '' FromTimeUI, '' ToTimeUI
	, '' MistakenBy, '' DecidedBy,'' AS PerformanceBy
	,  'Manual Void' AS 'Auto Void?'
    , '' Min_Trans , '' Max_Trans , '' Min_TransDate , '' Max_TransDate , '' Liveindicator
	, '' AS ListBettypes, '' AS ListBetteams, '' ListScore,'' Calc_HTTime,'' Calc_FTTime
	,  ms.MessageContent
	, CASE WHEN MAX(CASE WHEN bk.statusID IN (111,112,113) THEN 1 ELSE 0 END) = 1 THEN 'Yes' ELSE 'No' END AS 'Has Void Settled?'
FROM #temp_transid ms WITH (NOLOCK)																									
	INNER JOIN bodb02.dbo.bettrans bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102		
	AND bk.winlostdate between  @from AND @to
GROUP BY bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup, ms.MessageContent																							
ORDER BY winlostdate																									


DROP TABLE #message_tmp
DROP TABLE #temp_transid
