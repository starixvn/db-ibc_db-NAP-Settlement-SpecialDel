https://nexdev.net/issues/190432
/*db061/bodb_archive*/
--drop table #message_tmp																									
		
USE bodb_archive 
GO

DECLARE @from datetime, @to datetime																									
SET @from = '2023-06-29'																									
SET @to = '2023-07-01'																									
																									
CREATE TABLE #message_tmp (messageID INT, reason VARCHAR(50), transid BIGINT, MessageContent varchar(max))																								
CREATE TABLE #temp_transid (
transid bigint
,reason varchar(50)
, matchid INT
,sporttype tinyint
, sportName nVARCHAR(100)
, home nvarchar(200)
, away varchar(200)
, leaguename varchar(1000)
, LeagueGroup varchar(200)
, FunctionGroup varchar(100)
, VoidingHistoryId INT
, RequestId INT
, IssueTypeId TINYINT
, SubIssueTypeId TINYINT
, Request_CreatedDate DATETIME
, FromTimeUI DATETIME
, ToTimeUI DATETIME
, MessageContent varchar(max)
, IssueType varchar(200)
, SubIssueType varchar(200)
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
		, ms.Content_en
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
	--AND ms.MatchId > 0																								
	AND ms.IsTest = 0	
	

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
		, ms.Content_en
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
	AND ms.IsTest = 0																								
																										

/*Range archive*/
INSERT INTO #temp_transid (transid,reason,matchid, FunctionGroup, VoidingHistoryId, MessageContent)	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid, CASE WHEN VoidingHistoryId is null then 'SD' else 'TVS' END AS FunctionGroup, d.VoidingHistoryId, ms.MessageContent											
FROM #message_tmp ms with (nolock)																									
	INNER JOIN bodb_archive.dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	


/*Range active*/
INSERT INTO #temp_transid (transid,reason,matchid, FunctionGroup, VoidingHistoryId, MessageContent)	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid, CASE WHEN VoidingHistoryId is null then 'SD' else 'TVS' END AS FunctionGroup, d.VoidingHistoryId, ms.MessageContent													
FROM #message_tmp ms with (nolock)																									
	INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.transid = ms.TransId	


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
		
		UNION ALL																							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	bodb02.dbo.outright14 m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.teamid																						
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid

		UNION ALL																							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	dbo.outright_bk m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.teamid																						
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid
	) m																								
	INNER JOIN bodb02.dbo.League l WITH (NOLOCK)																								
		ON m.leagueid = l.leagueid																							
WHERE l.isTest = 0																
	
	
UPDATE d
SET RequestId = req.RequestId
, IssueTypeId = req.IssueTypeId 
, SubIssueTypeId  = req.SubIssueTypeId
, IssueType = req.IssueTypeName 
, SubIssueType  = req.SubIssueTypeName
, Request_CreatedDate = req.Request_CreatedDate
, FromTimeUI = req.FilterFromTransTime
, ToTimeUI = req.FilterToTransTime
FROM #temp_transid d WITH(NOLOCK)
	CROSS APPLY (
				SELECT r.RequestId,r.IssueTypeId,rd.SubIssueTypeId, r.CreatedDate AS Request_CreatedDate
				, rd.FilterFromTransTime, rd.FilterToTransTime
                , i.IssueTypeName, s.SubIssueTypeName
				FROM dbo.TicketVoiding_VoidingHistory_bk vt WITH(NOLOCK)
					INNER JOIN DBO.TicketVoiding_Request_bk r  WITH(NOLOCK) ON vt.RequestId = r.RequestId AND r.IsTest = 0
					INNER JOIN DBO.TicketVoiding_RequestDetail_bk rd  WITH(NOLOCK) ON r.RequestId = rd.RequestId
					LEFT JOIN bodb02.dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
					LEFT JOIN bodb02.dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON rd.SubIssueTypeId = s.SubIssueTypeId
				WHERE d.VoidingHistoryId = vt.VoidingHistoryId
		)req
WHERE d.FunctionGroup = 'TVS' AND VoidingHistoryId is not null

--Rang active
UPDATE d
SET RequestId = req.RequestId
, IssueTypeId = req.IssueTypeId 
, SubIssueTypeId  = req.SubIssueTypeId
, IssueType = req.IssueTypeName 
, SubIssueType  = req.SubIssueTypeName
, Request_CreatedDate = req.Request_CreatedDate
, FromTimeUI = req.FilterFromTransTime
, ToTimeUI = req.FilterToTransTime
FROM #temp_transid d WITH(NOLOCK)
	CROSS APPLY (
				SELECT r.RequestId,r.IssueTypeId,rd.SubIssueTypeId, r.CreatedDate AS Request_CreatedDate
				, rd.FilterFromTransTime, rd.FilterToTransTime
                ,i.IssueTypeName, s.SubIssueTypeName
				FROM bodb02.dbo.TicketVoiding_VoidingHistory vt WITH(NOLOCK)
					INNER JOIN bodb02.dbo.TicketVoiding_Request r  WITH(NOLOCK) ON vt.RequestId = r.RequestId AND r.IsTest = 0
					INNER JOIN bodb02.dbo.TicketVoiding_RequestDetail rd  WITH(NOLOCK) ON r.RequestId = rd.RequestId
					LEFT JOIN bodb02.dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
					LEFT JOIN bodb02.dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON rd.SubIssueTypeId = s.SubIssueTypeId
				WHERE d.VoidingHistoryId = vt.VoidingHistoryId
		)req
WHERE d.FunctionGroup = 'TVS' AND VoidingHistoryId is not null


SELECT																									
	ms.FunctionGroup, bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																		
    , COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, ms.MessageContent
    , 'VOID' AS ActionName
	, ms.RequestId, ms.IssueType, ms.SubIssueType,ms.Request_CreatedDate, ms.FromTimeUI, ms.ToTimeUI
    , ms.IssueTypeId, ms.SubIssueTypeId
FROM #temp_transid ms with (nolock)																									
	INNER JOIN bettrans_bk bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102																					
GROUP BY ms.FunctionGroup, bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup	
, ms.RequestId, ms.IssueType, ms.SubIssueType,ms.Request_CreatedDate, ms.FromTimeUI, ms.ToTimeUI, ms.MessageContent	, ms.IssueTypeId, ms.SubIssueTypeId																								
ORDER BY winlostdate

SELECT																									
	ms.FunctionGroup, bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																		
    , COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, ms.MessageContent
    , 'VOID' AS ActionName
	, ms.RequestId, ms.IssueType, ms.SubIssueType,ms.Request_CreatedDate, ms.FromTimeUI, ms.ToTimeUI
    , ms.IssueTypeId, ms.SubIssueTypeId
FROM #temp_transid ms with (nolock)																									
	INNER JOIN bodb02.dbo.bettrans14 bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102
GROUP BY ms.FunctionGroup, bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup	
, ms.RequestId, ms.IssueType, ms.SubIssueType,ms.Request_CreatedDate, ms.FromTimeUI, ms.ToTimeUI, ms.MessageContent	, ms.IssueTypeId, ms.SubIssueTypeId																								
ORDER BY winlostdate	

SELECT																									
	ms.FunctionGroup, bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup																		
    , COUNT(DISTINCT bk.transid) AS Bet_cnt																								
	, cast (SUM(bk.stake * bk.actualrate) as money) AS MemberTO_RM, cast(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, ms.MessageContent
    , 'VOID' AS ActionName
	, ms.RequestId, ms.IssueType, ms.SubIssueType,ms.Request_CreatedDate, ms.FromTimeUI, ms.ToTimeUI
    , ms.IssueTypeId, ms.SubIssueTypeId
FROM #temp_transid ms with (nolock)																									
	INNER JOIN bodb02.dbo.bettrans bk WITH(NOLOCK) ON bk.transid = ms.transid																								
	AND bk.currency <> 20																								
	AND bk.statusID = 102		
GROUP BY ms.FunctionGroup, bk.winlostdate, ms.Reason, bk.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup	
, ms.RequestId, ms.IssueType, ms.SubIssueType,ms.Request_CreatedDate, ms.FromTimeUI, ms.ToTimeUI, ms.MessageContent, ms.IssueTypeId, ms.SubIssueTypeId																									
ORDER BY winlostdate																									

DROP TABLE #message_tmp
DROP TABLE #temp_transid




--------------------------------------------------------------------------------------
/* Check function void of SD - Check on Central and SiteDB*/
/*
--DBTRANS/SITEDB

USE bodb02

SELECT *
FROM DBO.TVS_UserActionLog (NOLOCK) --keep 14 day
WHERE (
	SPNAME LIKE '%NAP_SpecialDelete_VoidParlayBet_Update%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidSingleBet_Update%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidByCurrency_Update%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidBetIdList_Upd%'
OR SPNAME LIKE '%NAP_BettransDelSpecialDel_EarlyKO%'
OR SPNAME LIKE '%NAP_SpecialDelete_VoidParlaySubVSBetRadar_Upd%'
)
AND 
(MATCHID IN (69675879,69683206,69695637)
OR TransId LIKE '%%'
)
*/