/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/
USE bodb_archive 
GO

DECLARE @from datetime, @to datetime																						
SET @from = '2025-09-10'																									
SET @to = '2025-10-01'																									
		
        

CREATE TABLE #message_tmp (messageID INT, reason VARCHAR(50), transid BIGINT, MessageContent varchar(max), [Date] DATETIME, CREATOR NVARCHAR(50), matchid INT)																									
CREATE TABLE #temp_transid (
transid bigint
,reason varchar(50)
, matchid INT
, sporttype tinyint
, sportName nVARCHAR(100)
, home nvarchar(200)
, away varchar(200)
, MessageContent varchar(max)
, [Date] DATETIME
, zzz_status NVARCHAR(100)
, zzz_Transdate DATETIME
, CREATOR NVARCHAR(50)
, IsArchived BIT DEFAULT(0)
, IsParlay  BIT DEFAULT(0)
, BETTIME DATETIME
, HDP1 MONEY
, HDP2 MONEY
, SCORE NVARCHAR(100)
, actual_stake MONEY
, CurrencyName NVARCHAR(50) 
, currency TINYINT
, betteam NVARCHAR(10)
, odds MONEY
, custid INT
, bettype SMALLINT
, IsUpdate BIT DEFAULT(0) 
, VoidingHistoryId BIGINT
, subtransid BIGINT
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
UNION ALL SELECT 'Early Kick Off'			, '%Due to%early%placed%considered%VOID%'
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
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent, Date, CREATOR, matchid)		
SELECT   ms.MessageId																									
		, COALESCE(v.Reason, 'Other Issues') AS Reason																		
		, t.transid		
		, ms.Content_en
        , CAST(ms.CreateTime AS DATE) AS Date
        , ms.creatorname AS CREATOR
        , ms.matchid
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
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent, Date, CREATOR, matchid)			
SELECT   ms.MessageId																									
		, COALESCE(v.Reason, 'Other Issues') AS Reason																		
		, t.transid		
		, ms.Content_en
        , CAST(ms.CreateTime AS DATE) AS Date
        , ms.creatorname AS CREATOR
        , ms.matchid
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


/*Range archive*/
BEGIN
				
	DELETE ms
    FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	
	WHERE d.VoidingHistoryId IS NOT NULL
    
    
    select count(distinct (transid)) from #message_tmp

   /* SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, ms.date, d.status, d.Transdate, ms.CREATOR, 1 AS IsArchived, 1 AS IsParlay
      --, bm.transdate			
		--, bm.hdp1, bm.hdp2, CAST(bm.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(bm.LiveAwayScore AS VARCHAR(10))
		--, bm.betteam, bm.odds, bm.custid, bm.bettype, b.currency
       -- , d.VoidingHistoryId
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN dbo.bettrans_bk b WITH (NOLOCK) ON b.transid = ms.TransId	
		INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.refno = b.refno AND ms.matchid = d.matchid
		--INNER HASH JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = d.transid AND d.matchid = bm.matchid
	WHERE d.VoidingHistoryId IS NULL
    
    
*/
    
   
    
   INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, [Date], zzz_status, zzz_Transdate, CREATOR)		
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, ms.date, d.status, d.Transdate, ms.CREATOR										
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	
	WHERE d.VoidingHistoryId IS NULL
    
	UPDATE s
	SET   s.actual_stake = B.actual_stake
		, s.currency = b.currency
		, s.HDP1 = b.hdp1
		, s.HDP2 = b.hdp2
		, s.SCORE = CAST(b.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(b.LiveAwayScore AS VARCHAR(10))
		, s.BETTIME = b.transdate
		, s.betteam = b.betteam
		, s.odds = b.odds
		, s.custid = b.custid
		, s.bettype = b.bettype
        , IsUpdate = 1
	FROM #temp_transid s
		CROSS APPLY (
			SELECT liveindicator, transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, custid, HDP1, HDP2, currency, odds
			FROM dbo.bettrans_bk b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		
   

	--parlay 
	INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, [Date], zzz_status, zzz_Transdate, CREATOR, IsArchived, IsParlay
        , currency, subtransid,actual_stake 
	)		
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, ms.date, d.status, d.Transdate, ms.CREATOR, 1 AS IsArchived, 1 AS IsParlay			
        , b.currency, d.transid as subtransid, b.actual_stake
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN dbo.bettrans_bk b WITH (NOLOCK) ON b.transid = ms.TransId	
		INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.refno = b.refno AND ms.matchid = d.matchid	
	WHERE d.VoidingHistoryId IS NULL
   
    
  
    UPDATE s
	SET   s.actual_stake = CASE WHEN b.actual_stake IS NULL THEN s.actual_stake ELSE b.actual_stake END
		--, s.currency = b.currency
		, s.HDP1 = b.hdp1
		, s.HDP2 = b.hdp2
		, s.SCORE = b.SCORE
		, s.BETTIME = b.transdate
		, s.betteam = b.betteam
		, s.odds = b.odds
		, s.custid = b.custid
		, s.bettype = b.bettype
        , IsUpdate = 1
        , IsParlay = 1
	FROM #temp_transid s
		CROSS APPLY (
			SELECT bm.transdate, actual_stake, bm.hdp1, bm.hdp2, CAST(bm.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(bm.LiveAwayScore AS VARCHAR(10)) AS SCORE
            , bm.betteam, bm.odds, bm.custid, bm.bettype
			FROM dbo.bettransm bM WITH (NOLOCK) 
			WHERE bm.transid = s.subtransid AND s.matchid = bm.matchid
		)b
END

/*Range active*/
/*BEGIN
	INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, [Date], zzz_status, zzz_Transdate, CREATOR)		
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, ms.date, d.status, d.Transdate, ms.CREATOR										
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.transid = ms.TransId	
	WHERE d.VoidingHistoryId IS NULL

	UPDATE s
	SET   s.actual_stake = b.actual_stake
		, s.CurrencyName = b.currencyname
		, s.HDP1 = b.hdp1
		, s.HDP2 = b.hdp2
		, s.SCORE = CAST(b.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(b.LiveAwayScore AS VARCHAR(10))
		, s.BETTIME = b.transdate
		, s.betteam = b.betteam
		, s.odds = b.odds
		, s.custid = b.custid
	FROM #temp_transid s
		CROSS APPLY (
			SELECT liveindicator, transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, Username, custid, HDP1, HDP2, currencyname, odds
			FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
			UNION 
			SELECT liveindicator, transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, Username, custid, HDP1, HDP2, currencyname, odds
			FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		--INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON b.currency = e.ExchangeId

	--parlay 
	INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, [Date], zzz_status, zzz_Transdate, CREATOR, IsParlay, BETTIME
		, HDP1, HDP2, SCORE
	)		
	SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent, ms.date, d.status, d.Transdate, ms.CREATOR, 1 AS IsParlay, bm.transdate
		, bm.hdp1, bm.hdp2, CAST(bm.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(bm.LiveAwayScore AS VARCHAR(10))
	FROM #message_tmp ms WITH (NOLOCK)																									
		INNER JOIN bodb02.dbo.bettrans b WITH (NOLOCK) ON b.transid = ms.TransId	
		INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.refno = b.refno AND d.custid = b.custid
		INNER JOIN dbo.bettransm bm WITH (NOLOCK) ON bm.transid = d.transid AND d.matchid = bm.matchid
	WHERE d.VoidingHistoryId IS NULL
END
*/
UPDATE d
SET d.sporttype =   m.sporttype
, d.sportName = m.SportName
, d.home = m.home
, d.away = m.away
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
																									
		/*UNION ALL																							
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
		WHERE	orid = d.matchid*/	
		
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
        
        UNION ALL																							
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
    
 /* 
SELECT	'SD' AS 'TVS/SD?', ms.Date AS DATE
, CASE WHEN s.IsDeposit = 1 THEN 'L' ELSE 'C' END AS SITE
, ms.SportName AS SPORTS
, ms.matchid AS MATCHID
, c.Username AS ACCOUNT
, b.typenamee AS BETTYPE
, bk.betteam AS BET
, bk.odds AS ODDS
, bk.currencyname AS CUR
, bk.actual_stake AS AMOUNT
, ms.home + ' -vs- ' + ms.away AS EVENT
, bk.HDP1, bk.HDP2
, CAST(bk.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(bk.LiveAwayScore AS VARCHAR(10)) AS SCORE
, ms.CREATOR
, ms.transid AS REFNO
, ms.zzz_status AS STATUS
, bk.transdate AS BETTIME
, ms.zzz_Transdate AS DELTIME
, ms.REASON
FROM #temp_transid ms WITH (NOLOCK)																									
	INNER JOIN bodb02.dbo.bettrans bk WITH(NOLOCK) ON bk.transid = ms.transid
    INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON bk.bettype = b.typeid
    INNER JOIN bodb02.dbo.vw_Customer c WITH(NOLOCK) ON bk.custid = c.custid
	INNER JOIN bodb02.dbo.Site s WITH(NOLOCK) ON c.site = s.site																	
ORDER BY ms.Date ASC 

SELECT	'SD' AS 'TVS/SD?', ms.Date AS DATE
, CASE WHEN s.IsDeposit = 1 THEN 'L' ELSE 'C' END AS SITE
, ms.SportName AS SPORTS
, ms.matchid AS MATCHID
, c.Username AS ACCOUNT
, b.typenamee AS BETTYPE
, bk.betteam AS BET
, bk.odds AS ODDS
, bk.currencyname AS CUR
, bk.actual_stake AS AMOUNT
, ms.home + ' -vs- ' + ms.away AS EVENT
, bk.HDP1, bk.HDP2
, CAST(bk.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(bk.LiveAwayScore AS VARCHAR(10)) AS SCORE
, ms.CREATOR
, ms.transid AS REFNO
, ms.zzz_status AS STATUS
, bk.transdate AS BETTIME
, ms.zzz_Transdate AS DELTIME
, ms.REASON
FROM #temp_transid ms WITH (NOLOCK)																									
	INNER JOIN bodb02.dbo.bettrans14 bk WITH(NOLOCK) ON bk.transid = ms.transid
    INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON bk.bettype = b.typeid
    INNER JOIN bodb02.dbo.vw_Customer c WITH(NOLOCK) ON bk.custid = c.custid
	INNER JOIN bodb02.dbo.Site s WITH(NOLOCK) ON c.site = s.site
ORDER BY ms.Date ASC 
*/
SELECT	'SD' AS 'TVS/SD?', ms.Date AS DATE
, CASE WHEN s.IsDeposit = 1 THEN 'L' ELSE 'C' END AS SITE
, ms.SportName AS SPORTS
, ms.matchid AS MATCHID
, c.Username AS ACCOUNT
, b.typenamee AS BETTYPE
, ms.betteam AS BET
, ms.odds AS ODDS
, e.currency AS CUR
, ms.actual_stake AS AMOUNT
, ms.home + ' -vs- ' + ms.away AS EVENT
, ms.HDP1, ms.HDP2
, ms.SCORE
, ms.CREATOR
, ms.transid AS REFNO
, ms.zzz_status AS STATUS
, ms.BETTIME
, ms.zzz_Transdate AS DELTIME
, ms.REASON
, ms.IsParlay
FROM #temp_transid ms WITH (NOLOCK)																									
	--INNER JOIN dbo.bettrans_BK bk WITH(NOLOCK) ON bk.transid = ms.transid
    INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON ms.bettype = b.typeid
    INNER JOIN bodb02.dbo.vw_Customer c WITH(NOLOCK) ON ms.custid = c.custid
	INNER JOIN bodb02.dbo.Site s WITH(NOLOCK) ON c.site = s.site
	INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON ms.currency = e.ExchangeId
ORDER BY ms.Date ASC 

DROP TABLE #message_tmp
DROP TABLE #temp_transid
DROP TABLE #VoidReasonPattern