/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/

DECLARE @from datetime, @to datetime																					
SET @from = '2025-09-01'																								
SET @to = '2025-10-01'

CREATE TABLE #message_tmp (messageID INT, reason VARCHAR(50), transid BIGINT, MessageContent varchar(max), [Date] DATETIME)																								
CREATE TABLE #temp_transid (
transid bigint
,reason varchar(50)
, matchid INT
, MessageContent varchar(max)
, winlost SMALLMONEY
, actual_stake SMALLMONEY
, stake SMALLMONEY
, actualrate float
, statuswinlost tinyint
, winlostdate DATETIME
, [Date] DATETIME
, oddsspread MONEY
, bettype SMALLINT
, odds SMALLMONEY
, isDecimalOdd BIT
, oddstype TINYINT
, modds SMALLMONEY
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
UNION ALL SELECT 'Wrong Odds'				, '%Due to%wrong%odds displayed%VOID%'
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
UNION ALL SELECT 'Reduced Over'				, '%Due to%scheduled overs being reduced%considered%VOID%'			
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
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent, Date)																									
SELECT   ms.MessageId																									
		, COALESCE(v.Reason, 'Other Issues') AS Reason																		
		, t.transid		
		, ms.Content_en
        , CAST(ms.CreateTime AS DATE) AS Date
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
INSERT INTO #message_tmp (messageID, reason, transid, MessageContent, Date)																									
SELECT   ms.MessageId																									
		, COALESCE(v.Reason, 'Other Issues') AS Reason																		
		, t.transid		
		, ms.Content_en
        , CAST(ms.CreateTime AS DATE) AS Date
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
INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, [Date])	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent	, ms.date										
FROM #message_tmp ms WITH (NOLOCK)																									
	INNER JOIN dbo.zzzbettrans_bk d WITH (NOLOCK) ON d.transid = ms.TransId	
WHERE d.VoidingHistoryId IS NULL

/*Range active*/
INSERT INTO #temp_transid (transid,reason,matchid, MessageContent, [Date])	
SELECT DISTINCT ms.TransId, ms.reason, d.matchid, ms.MessageContent	, ms.date											
FROM #message_tmp ms WITH (NOLOCK)																									
	INNER JOIN bodb02.dbo.zzzbettrans d WITH (NOLOCK) ON d.transid = ms.TransId	
WHERE d.VoidingHistoryId IS NULL

DECLARE  @odds              SMALLMONEY
	    ,@winlost           MONEY

UPDATE t
SET oddsspread = b.oddsspread
	,actual_stake = b.actual_stake
	,statuswinlost = B.statuswinlost
	,winlostdate = b.winlostdate
	,actualrate = ISNULL(b.actualrate,0)
	,stake = ISNULL(b.stake,0)
	,bettype = b.bettype
	,odds = b.odds
	,isDecimalOdd = CASE WHEN (ot.oddstype = 1 OR b.bettype = 38) THEN 1 ELSE 0 END
	,oddstype = b.oddstype
	,modds = b.modds
FROM #temp_transid t
   INNER JOIN bodb02.dbo.bettrans b  WITH (NOLOCK)  ON  t.transid = b.transid 
   LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b.bettype
WHERE  b.currency <> 20																								
AND b.statusID = 102

UPDATE t
SET oddsspread = b.oddsspread
	,actual_stake = b.actual_stake
	,statuswinlost = B.statuswinlost
	,winlostdate = b.winlostdate
	,actualrate = ISNULL(b.actualrate,0)
	,stake = ISNULL(b.stake,0)
	,bettype = b.bettype
	,odds = b.odds
	,isDecimalOdd = CASE WHEN (ot.oddstype = 1 OR b.bettype = 38) THEN 1 ELSE 0 END
	,oddstype = b.oddstype
	,modds = b.modds
FROM #temp_transid t
   INNER JOIN bodb02.dbo.bettrans14 b  WITH (NOLOCK)  ON  t.transid = b.transid 
   LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b.bettype
WHERE b.currency <> 20																								
AND b.statusID = 102

UPDATE t
SET oddsspread = b.oddsspread
	,actual_stake = b.actual_stake
	,statuswinlost = B.statuswinlost
	,winlostdate = b.winlostdate
	,actualrate = ISNULL(b.actualrate,0)
	,stake = ISNULL(b.stake,0)
	,bettype = b.bettype
	,odds = b.odds
	,isDecimalOdd = CASE WHEN (ot.oddstype = 1 OR b.bettype = 38) THEN 1 ELSE 0 END
	,oddstype = b.oddstype
	,modds = b.modds
FROM #temp_transid t
   INNER JOIN dbo.bettrans_bk b  WITH (NOLOCK)  ON  t.transid = b.transid 
   LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b.bettype
WHERE b.currency <> 20																								
AND b.statusID = 102

UPDATE b
SET 
@odds = CASE WHEN bettype IN (468,469) THEN odds
								 ELSE (CASE WHEN odds < 0 THEN 1 
											WHEN isDecimalOdd = 1 THEN b.odds - 1 ----/*DECIMAL ONLY*/
											ELSE odds 
										END)
						END
,@winlost = CASE 
				WHEN bettype IN (468,469) THEN CASE 
													WHEN statuswinlost IN (2,4) THEN b.actual_stake + b.stake * @odds
													WHEN statuswinlost IN (0,6) THEN b.actual_stake 
													END   
				ELSE
				CASE
					WHEN statuswinlost = 2 THEN CASE WHEN b.oddstype = 6 AND b.modds = 0 THEN b.actual_stake + b.stake * odds * (oddsspread/100) -- oddsspread > 0: WON
												ELSE b.actual_stake + b.stake * @odds
												END
					WHEN statuswinlost = 1 THEN B.actual_stake + B.stake * @odds * 0.5
					WHEN statuswinlost IN (0,6) THEN b.actual_stake
					WHEN statuswinlost = 3 THEN b.actual_stake * 0.5
					WHEN statuswinlost = 4 THEN  CASE WHEN b.oddstype = 6  AND b.modds = 0 THEN b.actual_stake * (1 - ABS(oddsspread/100))
													ELSE 0
													END
				END
			END   
,winlost = @winlost
FROM #temp_transid b

SELECT MONTH(date) AS MONTH_Time, transid, reason, winlost, actual_stake,stake, actualrate, statuswinlost
, CAST (stake * actualrate AS MONEY) AS member_TO
, CAST ((winlost-actual_stake)*actualrate AS MONEY) AS member_winlost
FROM #temp_transid
   
SELECT	DISTINCT 											
	 'SD' AS 'TVS/SD?'
	, YEAR(ms.date) AS YEAR_Time
	, MONTH(ms.date) AS MONTH_Time
    , ms.Reason
    , SUM (CAST (stake * actualrate AS MONEY))  AS member_TO
    , SUM(CAST ((ms.winlost-ms.actual_stake) * actualrate AS MONEY)) AS member_winlost
FROM #temp_transid ms WITH (NOLOCK)		
GROUP BY ms.Reason, YEAR(ms.date), MONTH(ms.date) 


DROP TABLE #message_tmp
DROP TABLE #temp_transid
DROP TABLE #VoidReasonPattern

