/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/
USE bodb_archive 
GO

DECLARE @from datetime, @to datetime																						
SET @from = '2025-10-01'																									
SET @to = '2025-11-01'																									
																									
CREATE TABLE #message_tmp (messageID INT, reason VARCHAR(50), transid BIGINT, MessageContent varchar(max), matchid INT)																										
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
, IsParlay  BIT DEFAULT(0)
, zzz_status NVARCHAR(100)
, winlostdate SMALLDATETIME
, currency TINYINT
, actual_stake MONEY
, statusId INT
, actualrate FLOAT
, stake MONEY
, tpositiontaking SMALLMONEY
, subtransid BIGINT
, betteam NVARCHAR(10)
, selection INT
, refno BIGINT
, IsArchived BIT DEFAULT(0)
)

CREATE TABLE #VoidReasonPattern (
    Reason NVARCHAR(50),
	Pattern NVARCHAR(255)
);
INSERT INTO #VoidReasonPattern (Reason, Pattern)
		  SELECT 'Danger Accepted'			, '%Due to%erroneously accepted%danger%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%match has been completed%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%goal% has been completed%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%Booking% has been completed%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%corner% has been completed%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%the first penalty kick had been taken%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%a goal was scored from a penalty awarded%%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%an official decision to award%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%1st Half has been completed%considered%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%wrong market offered caused by penalty retaken%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%the penalty shootout had been started in the match between%VOID%'
UNION ALL SELECT 'Danger Accepted'			, '%Due to%penalty kick had been taken%VOID%'
UNION ALL SELECT 'Wrong Odds'				, '%Due to%wrong%odds%VOID%'
UNION ALL SELECT 'Wrong Score'				, '%Due to%wrong score displayed%VOID%' 
UNION ALL SELECT 'Wrong Score'				, '%Due to%an official decision to cancel%considered%VOID%'
UNION ALL SELECT 'Wrong HDP'				, '%Due to%wrong HDP displayed%considered%VOID%'
UNION ALL SELECT 'Wrong 1st HDP'			, '%Due to%wrong%HDP displayed%considered%VOID%'
UNION ALL SELECT 'Wrong OU'					, '%Due to%wrong OU displayed%considered%VOID%' 
UNION ALL SELECT 'Wrong 1st OU'				, '%Due to%wrong%OU displayed%considered%VOID%' 
UNION ALL SELECT 'Red card'					, '%Due to%wrong market offered caused by no indication%considered%VOID%'
UNION ALL SELECT 'Red card'					, '%Due to%wrong market offered caused by wrong indication%considered%VOID%'
UNION ALL SELECT 'Red card'					, '%Due to%red card being awarded to%considered%VOID%'
UNION ALL SELECT 'Red card'					, '%Due to%wrong odds offered on replacement of%considered%VOID%' 
UNION ALL SELECT 'Red card'					, '%Due to%an official decision to cancel%team%after reviewing VAR for the match between%considered%VOID%'
UNION ALL SELECT 'Early Kick Off'			, '%Due to%early%considered%VOID%'
UNION ALL SELECT 'Wrong Kick Off Time'		, '%Due to%wrong%time displayed%considered%VOID%'
UNION ALL SELECT 'Wrong Offered Name'		, '%Due to%wrong team name displayed%considered%VOID%' 
UNION ALL SELECT 'Wrong Offered Name'		, '%Due to%wrong league name displayed%considered%VOID%'
UNION ALL SELECT 'Technical Error'			, '%Due to%technical error%VOID%' 
UNION ALL SELECT 'Second Team Batting'		, '%Following a review of the match between%considered%VOID%'
UNION ALL SELECT 'Abandoned'				, '%Due to%abandoned%considered%VOID%'								
UNION ALL SELECT 'Reduced Over'				, '%Due to%number of scheduled%being reduced%considered%VOID%'			
UNION ALL SELECT 'Not Participate'			, '%Due to%Player%did not participate%VOID%'				
UNION ALL SELECT 'Wrong Market Offered'		, '%Due to%market offered%Live betting%match%considered%VOID%'				
UNION ALL SELECT 'Match Completed'			, '%Due to%Wicket%has been completed%considered%VOID%'				
UNION ALL SELECT 'Match Early Completed'	, '%The match between%has been completed earlier%considered%VOID%'	
UNION ALL SELECT 'Wrong Team Name'			, '%Due to%wrong%team name displayed%considered%VOID%'				
UNION ALL SELECT 'Abnormal Bet'				, '%Due to%abnormal bet%VOID%'		
UNION ALL SELECT 'Game Crashed Void Live'	, '%Due to%technical%issue%considered%VOID%' --SubType
UNION ALL SELECT 'Should Not Offer'			, '%Due to%should not offer%match%considered%VOID%' --SubType				
UNION ALL SELECT 'Restart'					, '%Due to%has been restart%considered%VOID%' --SubType


/*Range archive*/																							
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent, matchid)																									
SELECT   ms.MessageId																									
		, COALESCE(v.Reason, 'Other Issues') AS Reason																		
		, t.transid		
		, ms.Content_en, ms.matchid
FROM DBMSG.bodb_Message_Archive.dbo.[Msg_Archive] ms WITH (NOLOCK)
	CROSS APPLY (SELECT DISTINCT BetTransId																								
			FROM DBMSG.bodb_Message_Archive.[dbo].[MsgTarget_Archive] mt1 WITH (NOLOCK)																				
			WHERE mt1.MessageId= ms.MessageId																						
				AND mt1.isDeleted = 0																					
				AND mt1.BettransId <> ''																					
			) mt	
	CROSS APPLY (SELECT LTRIM(RTRIM(value)) AS transid FROM STRING_SPLIT(mt.BetTransId,',')) AS t
	LEFT JOIN #VoidReasonPattern v ON ms.Content_en LIKE v.Pattern
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to																									
	AND ms.IsTest = 0	
	AND Content_en LIKE '%Due to%VOID%'

/*Range active*/																							
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent, matchid)																									
SELECT   ms.MessageId																									
		, COALESCE(v.Reason, 'Other Issues') AS Reason																		
		, t.transid		
		, ms.Content_en, ms.matchid
FROM DBMSG.bodb_Message.dbo.[Msg] ms WITH (NOLOCK)	
	CROSS APPLY (SELECT DISTINCT BetTransId																								
			FROM DBMSG.bodb_Message.[dbo].[MsgTarget] mt1 WITH (NOLOCK)																						
			WHERE mt1.MessageId= ms.MessageId																						
				AND mt1.isDeleted = 0																					
				AND mt1.BettransId <> ''																					
			) mt
	CROSS APPLY (SELECT LTRIM(RTRIM(value)) AS transid FROM STRING_SPLIT(mt.BetTransId,',')) AS t
	LEFT JOIN #VoidReasonPattern v ON ms.Content_en LIKE v.Pattern
WHERE ms.CreateTime >= @from AND ms.CreateTime < @to																									
	AND ms.IsTest = 0																								
	AND Content_en LIKE '%Due to%VOID%'	

DELETE ms
FROM #message_tmp ms WITH (NOLOCK)																									
	INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	
WHERE d.VoidingHistoryId IS NOT NULL
    
/*Range archive*/
BEGIN
	--single
	INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, zzz_status)	
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, d.status										
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	
	WHERE d.VoidingHistoryId IS NULL

	--parlay 
	INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, IsParlay, zzz_status, subtransid, currency, selection, betteam, refno, IsArchived)			
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, 1 AS IsParlay, d.status, d.transid as subtransid, b.currency
	, CASE WHEN ISNULL(b.oddsspread,0) <> 3 THEN b.hdp2 --Mix/System parlay
		   WHEN ISNULL(b.oddsspread,0) = 3 THEN b.betid --Hybrid parlay
		   ELSE 0 END
	, b.betteam, b.refno, 1 AS IsArchived	
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN dbo.bettrans_bk b WITH (NOLOCK) ON b.transid = ms.TransId	
		INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.refno = b.refno AND ms.matchid = d.matchid	
	WHERE d.VoidingHistoryId IS NULL

	UPDATE s
	SET   s.actual_stake = b.actual_stake
		, s.currency = b.currency
		, s.statusId = b.statusID
		, s.stake = b.stake
		, s.actualrate = b.actualrate
		, s.winlostdate = b.winlostdate
	FROM #temp_transid s
		CROSS APPLY (
			SELECT winlostdate, statusID, stake, actualrate, actual_stake, TransId, bettype, custid, currency
			FROM dbo.bettrans_bk b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
	
	UPDATE s
	SET   s.actual_stake = b.actual_stake
		, s.statusId = b.statusID
		, s.stake = b.stake
		, s.actualrate = b.actualrate
		, s.winlostdate = b.winlostdate
	FROM #temp_transid s
		CROSS APPLY (
			SELECT winlostdate, statusID, stake, actualrate, actual_stake, TransId, bettype, custid, currency
			FROM dbo.bettransm bm WITH (NOLOCK) 
			WHERE bm.transid = s.subtransid AND s.matchid = bm.matchid
		)b
END

/*Range active*/
BEGIN
	--single
	INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, zzz_status)	
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, d.status													
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.transid = ms.TransId	
	WHERE d.VoidingHistoryId IS NULL
	
	UPDATE s
	SET   s.actual_stake = b.actual_stake
		, s.currency = b.currency
		, s.statusId = b.statusID
		, s.stake = b.stake
		, s.actualrate = b.actualrate
		, s.tpositiontaking = b.tpositiontaking
		, s.winlostdate = b.winlostdate
	FROM #temp_transid s
		CROSS APPLY (
			SELECT winlostdate, statusID, stake, actualrate, actual_stake, TransId, bettype, custid, currency, tpositiontaking
			FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
			UNION 
			SELECT winlostdate, statusID, stake, actualrate, actual_stake, TransId, bettype, custid, currency, tpositiontaking
			FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b

	--parlay 
	INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, IsParlay, zzz_status, subtransid, selection, betteam, stake, refno)	
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, 1 AS IsParlay, d.status, d.transid AS subtransid
	, CASE WHEN ISNULL(b.oddsspread,0) <> 3 THEN b.hdp2 --Mix/System parlay
		   WHEN ISNULL(b.oddsspread,0) = 3 THEN b.betid --Hybrid parlay
		   ELSE 0 END
	, b.betteam, b.stake, b.refno
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN bodb02.dbo.bettrans b WITH (NOLOCK) ON b.transid = ms.TransId	
		INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.refno = b.refno AND d.custid = b.custid
		INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = d.transid AND d.matchid = bm.matchid
	WHERE d.VoidingHistoryId IS NULL
END

DELETE ms
FROM #message_tmp ms WITH (NOLOCK)																									
	INNER JOIN #temp_transid d WITH (NOLOCK) ON d.transid = ms.TransId
        
---Update for case MBU T5 not copy zzzbetrans_bk, T6 delete zzzbettrans => miss data 
IF EXISTS ( SELECT TOP 1 1 FROM #message_tmp)
BEGIN
    INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, zzz_status)		
    SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, d.status								
    FROM #message_tmp ms WITH (NOLOCK)																									
        INNER JOIN bodb02.dbo.TicketVoiding_VoidedTransaction d WITH (NOLOCK) ON d.transid = ms.TransId	
END


	 IF EXISTS ( SELECT TOP 1 1 FROM #temp_transid WHERE isparlay = 1 AND betteam = '1' AND statusID = 102)
     BEGIN
         UPDATE t
         SET t.stake = CAST (t.stake/t.selection AS FLOAT)
         FROM #temp_transid t
         WHERE isparlay = 1 AND betteam = '1' AND t.statusID = 102
     END
     
     IF EXISTS ( SELECT TOP 1 1 FROM #temp_transid WHERE isparlay = 1 AND betteam <> '1' AND statusID = 102)
     BEGIN
          
          ;WITH CTE_Sumstake AS(
            SELECT SUM((bp.stake / SUBSTRING(CAST(bp.Serial AS VARCHAR(20)), 2, 2))) AS Sumstake
                   ,bp.Refno
                   ,bp.TransId --Sub ticket
            FROM DBTRANS.bodb02.dbo.BetParlayDetail bp (NOLOCK) 
            WHERE EXISTS ( SELECT TOP 1 1 FROM #temp_transid t
                                           WHERE t.IsParlay = 1 AND t.betteam <> '1' AND bp.refno = t.refno AND bp.transid = t.transid AND t.statusID = 102)
            GROUP BY Refno, TransId
            )
         UPDATE t
         SET t.stake = cte.Sumstake
         FROM #temp_transid t
             INNER JOIN CTE_Sumstake cte ON t.refno = cte.refno AND t.transid = cte.transid
         WHERE IsParlay = 1 AND betteam <> '1' AND t.statusID = 102
     END

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

IF EXISTS ( SELECT TOP 1 1 FROM #temp_transid WHERE sportname IS NULL)
BEGIN
   UPDATE d
    SET d.sporttype =   m.sporttype
    , d.sportName = m.SportName
    , d.home = m.home
    , d.away = m.away
    , d.leaguename = l.leaguename
    , d.LeagueGroup = 'Others'																		
    FROM #temp_transid d
    CROSS APPLY (																								
            SELECT  matchid, League3rdId , h.teamname as home, a.teamname as away, s.SportName, m.sporttype		
            FROM	bodb02.dbo.Match3rd m WITH (NOLOCK)																						
                LEFT JOIN bodb02.dbo.team3rd h WITH (NOLOCK) on h.team3rdid = m.homeid																						
                LEFT JOIN bodb02.dbo.team3rd a WITH (NOLOCK) on a.team3rdid = m.awayid																						
                LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = m.sporttype																						
            WHERE	Match3rdId = d.matchid	

            UNION ALL																							
            SELECT  matchid, League3rdId , h.teamname as home, a.teamname as away, s.SportName, m.sporttype		
            FROM	bodb02.dbo.Match3rd14 m WITH (NOLOCK)																						
                LEFT JOIN bodb02.dbo.team3rd h WITH (NOLOCK) on h.team3rdid = m.homeid																						
                LEFT JOIN bodb02.dbo.team3rd a WITH (NOLOCK) on a.team3rdid = m.awayid																						
                LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = m.sporttype																						
            WHERE	Match3rdId = d.matchid	

            UNION ALL																							
            SELECT  matchid, League3rdId , h.teamname as home, a.teamname as away, s.SportName, m.sporttype			
            FROM	dbo.Match3rd_BK m WITH (NOLOCK)																						
                LEFT JOIN bodb02.dbo.team3rd h WITH (NOLOCK) on h.team3rdid = m.homeid																						
                LEFT JOIN bodb02.dbo.team3rd a WITH (NOLOCK) on a.team3rdid = m.awayid																						
                LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = m.sporttype																						
            WHERE	Match3rdId = d.matchid
        ) m																								
        INNER JOIN bodb02.dbo.League3rd l WITH (NOLOCK)																								
            ON m.League3rdId = l.League3rdId																							
    WHERE l.isTest = 0	
END
	
SELECT	DISTINCT CASE WHEN ms.Reason LIKE '%Abnormal Bet%' THEN 'No' ELSE 'Yes' END IsMonthly																											
	, 'SD' AS 'TVS/SD?', ms.winlostdate
	, YEAR(ms.winlostdate) AS YEAR_winlostdate
	, MONTH(ms.winlostdate) AS MONTH_winlostdate
	, ms.Reason, ms.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename, ms.LeagueGroup																		
    , COUNT(DISTINCT ms.transid) AS Bet_cnt		
	, CAST(SUM(ms.stake * ms.actualrate) as money) AS MemberTO_RM
	, CAST(SUM ((1-tpositiontaking)* stake * actualrate) as money) AS House_TO_RM	
	, 'VOID' AS ActionName
	, '' AS Function_SDName
	, '' AS RequestId, '' TotalTicket, '' TotalTicket_Parlay, '' Bet_cnt_Parlay
    , '' IssueType, '' SubIssueType
	, '' AS CreatedBy, '' CreatedDate,'' AS Duration, '' FromTimeUI, '' ToTimeUI
	, '' MistakenBy, '' DecidedBy,'' AS PerformanceBy
	,  'Manual Void' AS 'Auto Void?'
    , '' Min_Trans , '' Max_Trans , '' Min_TransDate , '' Max_TransDate , '' Liveindicator
	, '' AS ListBettypes, '' AS ListBetteams, '' ListScore,'' Calc_HTTime,'' Calc_FTTime
	,  ms.MessageContent
	, CASE WHEN MAX(CASE WHEN ms.zzz_status IN ('LOSE', 'DRAW','WON') THEN 1 ELSE 0 END) = 1 THEN 'Yes' ELSE 'No' END AS 'Has Void Settled?'
FROM #temp_transid ms WITH (NOLOCK)																									
WHERE ms.currency NOT IN (20,72)																							
	AND ms.statusID = 102	
	AND ms.winlostdate between  @from AND @to
GROUP BY ms.winlostdate, ms.Reason, ms.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup, ms.MessageContent																							
ORDER BY winlostdate ASC 

DROP TABLE #message_tmp
DROP TABLE #temp_transid
DROP TABLE #VoidReasonPattern