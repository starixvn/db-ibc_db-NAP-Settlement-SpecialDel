/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/

USE bodb_archive
GO

DECLARE @from datetime, @to datetime																					
SET @from = '2025-07-01'																									
SET @to = '2025-08-01'																									
																								
CREATE TABLE #temp_transid (
  Winlostdate SMALLDATETIME
, Matchid INT
, RequestId INT
, IssueType varchar(200)
, SubIssueType varchar(200)
, UserId INT
, CreatedDate DATETIME
, MistakenBy NVARCHAR(200)
, DecidedBy NVARCHAR(200)
, Action_Req NVARCHAR(50)
, IssueTypeId INT
, SubIssueTypeId INT
)

CREATE TABLE #temp_Ticket (
 RequestId INT
, MatchId INT
, TransId BIGINT
, statusID TINYINT
, stake MONEY
, actualrate FLOAT
, winlostdate SMALLDATETIME
, bettype SMALLINT
, statuswinlost tinyint
, [Date] DATETIME
, oddsspread MONEY
, odds SMALLMONEY
, isDecimalOdd BIT
, oddstype TINYINT
, modds SMALLMONEY
, winlost MONEY
, actual_stake MONEY
, CreatedDate	DATETIME
, IssueType VARCHAR(200)
)

/**********************************************************RANGE ACTIVE*************************************************************/

INSERT #temp_transid (RequestId, IssueTypeId ,SubIssueTypeId, CreatedDate 
, MistakenBy , DecidedBy , UserId 
, Action_Req 
, matchid
,IssueType
,SubIssueType
)
SELECT r.RequestId, r.IssueTypeId, rd.SubIssueTypeId,r.CreatedDate, rd.FilterFromTransTime, rd.FilterToTransTime
,r.MistakenBy, r.DecidedBy, r.UserId, r.ActionId, rd.MatchId
  , i.IssueTypeName, s.SubIssueTypeName
FROM DBTRANS.bodb02.dbo.TicketVoiding_Request r  WITH(NOLOCK) 
	CROSS APPLY (
          SELECT TOP (1) rd.SubIssueTypeId, CASE WHEN rd.transids LIKE '%IsMainMatch="true"%' THEN rd.MatchId 
												 WHEN r.IssueTypeId IN (13,17,20) THEN NULL 
												 ELSE rd.MatchId END MatchId
		  , rd.FilterFromTransTime, rd.FilterToTransTime
          FROM  DBTRANS.bodb02.dbo.TicketVoiding_RequestDetail rd  WITH(NOLOCK) 
          WHERE r.RequestId = rd.RequestId
           ORDER BY rd.Id ASC
		  )rd
    LEFT JOIN DBTRANS.bodb02.dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
	LEFT JOIN DBTRANS.bodb02.dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON rd.SubIssueTypeId = s.SubIssueTypeId
WHERE r.IsTest = 0
AND r.CreatedDate >= @from AND r.CreatedDate < @to

INSERT INTO #temp_Ticket(
	RequestId, matchid, TransId  
	, statusID 
	, stake 
	, actualrate 
	, winlostdate 
	, bettype 
	, statuswinlost
	, isDecimalOdd
	, modds
	, IssueType
	, CreatedDate
    , actual_stake
    , oddstype
	, oddsspread
    , odds
)
SELECT t.RequestId, t.Matchid, s.TransId
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.winlostdate 
	, s.bettype 
	, b.statuswinlost
	, CASE WHEN (ot.oddstype = 1 OR b.bettype = 38) THEN 1 ELSE 0 END
	, b.modds
	, IssueType
	, CreatedDate
    , b.actual_stake
    , b.oddstype
	, b.oddsspread
    , b.odds
FROM #temp_transid t
	INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) ON t.RequestId = s.RequestId
	CROSS APPLY (
		SELECT transdate, statusID, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, betdaqid, currency, oddsspread, actual_stake, statuswinlost, odds, oddstype, modds
		FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
		UNION 
		SELECT transdate, statusID, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, betdaqid, currency, oddsspread, actual_stake, statuswinlost, odds, oddstype, modds
		FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
	)b
	LEFT JOIN bodb02.dbo.zzzbettrans z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
	LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b.bettype
WHERE     b.currency <> 20																								
AND b.statusID = 102   

    
/**********************************************************RANGE ARCHIVE*************************************************************/
INSERT #temp_transid (RequestId, IssueTypeId ,SubIssueTypeId, CreatedDate 
, MistakenBy , DecidedBy , UserId 
, Action_Req 
, matchid
,IssueType
,SubIssueType
)
SELECT r.RequestId, r.IssueTypeId, rd.SubIssueTypeId,r.CreatedDate, rd.FilterFromTransTime, rd.FilterToTransTime
,r.MistakenBy, r.DecidedBy, r.UserId, r.ActionId, rd.MatchId
  , i.IssueTypeName , s.SubIssueTypeName
FROM dbo.TicketVoiding_Request_bk r  WITH(NOLOCK) 
		CROSS APPLY (
          SELECT TOP (1) rd.SubIssueTypeId, CASE WHEN rd.transids LIKE '%IsMainMatch="true"%' THEN rd.MatchId 
												 WHEN r.IssueTypeId IN (13,17,20) THEN NULL 
												 ELSE rd.MatchId END MatchId
		  , rd.FilterFromTransTime, rd.FilterToTransTime
          FROM  dbo.TicketVoiding_RequestDetail_bk rd  WITH(NOLOCK) 
          WHERE r.RequestId = rd.RequestId
		  ORDER BY rd.Id ASC
          )rd
    LEFT JOIN DBTRANS.bodb02.dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
	LEFT JOIN DBTRANS.bodb02.dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON rd.SubIssueTypeId = s.SubIssueTypeId
WHERE r.IsTest = 0
AND r.CreatedDate >= @from AND r.CreatedDate < @to
AND NOT EXISTS ( SELECT TOP 1 1 FROM #temp_transid WHERE r.RequestId = RequestId)
 
INSERT INTO #temp_Ticket(
	RequestId, matchid, TransId  
	, statusID 
	, stake 
	, actualrate 
	, winlostdate 
	, bettype 
	, statuswinlost
	, isDecimalOdd
	, modds
	, IssueType
	, CreatedDate
    , actual_stake
    , oddstype
	, oddsspread
    , odds
)
SELECT t.RequestId, t.Matchid, s.TransId
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.winlostdate 
	, s.bettype 
	, b.statuswinlost
	, CASE WHEN (ot.oddstype = 1 OR b.bettype = 38) THEN 1 ELSE 0 END
	, b.modds
	, IssueType
	, CreatedDate
    , b.actual_stake
    , b.oddstype
	, b.oddsspread
    , b.odds
FROM #temp_transid t
	INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId
	CROSS APPLY (
			SELECT transdate, statusID, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, betdaqid, currency, oddsspread, actual_stake, statuswinlost, odds, oddstype, modds
			FROM dbo.bettrans_bk b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
	LEFT JOIN bodb02.dbo.zzzbettrans z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
	LEFT JOIN bodb02.dbo.f_Set_OddsTypeBettypes() AS ot ON ot.bettype = b.bettype
WHERE     b.currency <> 20																								
AND b.statusID = 102   
 
DECLARE  @odds              MONEY
	    ,@winlost           MONEY

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
FROM #temp_Ticket b


select MONTH(CreatedDate) AS MONTH_Time, transid, IssueType, winlost, actual_stake,stake, actualrate, statuswinlost
, CAST (stake * actualrate AS MONEY) AS member_TO
, CAST ((winlost-actual_stake)*actualrate AS MONEY) AS member_winlost
,  RequestId
from #temp_Ticket
   
           
SELECT	DISTINCT 											
	 'TVS' AS 'TVS/SD?'
	, YEAR(ms.CreatedDate) AS YEAR_Time
	, MONTH(ms.CreatedDate) AS MONTH_Time
    , ms.IssueType aS reason
    , SUM (CAST (stake * actualrate AS MONEY))  AS _TO
    , SUM(CAST ((ms.winlost-ms.actual_stake) * actualrate AS MONEY)) AS winlost
FROM #temp_Ticket ms WITH (NOLOCK)		
GROUP BY ms.IssueType, YEAR(ms.CreatedDate), MONTH(ms.CreatedDate) 


DROP TABLE #temp_transid
DROP TABLE #temp_Ticket
