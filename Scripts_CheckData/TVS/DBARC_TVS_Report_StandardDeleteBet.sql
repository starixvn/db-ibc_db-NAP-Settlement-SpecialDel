/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/

USE bodb_archive
GO

DECLARE @from datetime, @to datetime ,@RequestInfoGetCalcTimes VARBINARY(MAX) = NULL																									
SET @from = '2025-09-01'																									
SET @to = '2025-10-01'																									
																									
CREATE TABLE #temp_transid (
  Winlostdate	SMALLDATETIME
, Matchid		INT
, sporttype		tinyint
, sportName		NVARCHAR(100)
, home			NVARCHAR(200)
, away			NVARCHAR(200)
, RequestId		INT
, IssueType		NVARCHAR(200)
, UserId		INT
, CreatedDate	DATETIME
, LastVoidedBy	INT
, IssueTypeId	INT
)
CREATE TABLE #temp_Ticket (
	RequestId INT
	,MatchId INT
    , TransId	  BIGINT
	, Transdate DATETIME
	, statusID TINYINT
	, stake MONEY
	, actualrate FLOAT
	, actual_stake MONEY
	, winlostdate SMALLDATETIME
	, bettype SMALLINT
	, betteam NVARCHAR(10)
	, livehomescore SMALLINT
	, liveawayscore SMALLINT 
    , Transid_void BIGINT
	, IsArchived BIT DEFAULT(0)
	, zzz_status NVARCHAR(100)
	, zzz_Transdate DATETIME
	, sporttype tinyint
    , sportName nVARCHAR(100)
    , home nvarchar(200)
    , away varchar(200)
	, LastVoidedBy	INT
	, REASON varchar(200)
	, [Date] DATETIME
	, IsParlay  BIT DEFAULT(0)
	, Username NVARCHAR(50)
	, custid INT
	, HDP1 MONEY
	, HDP2 MONEY
	, CurrencyName NVARCHAR(50) 
	, odds MONEY
	, currency TINYINT
)

/**********************************************************RANGE ACTIVE*************************************************************/

INSERT #temp_transid (RequestId, IssueTypeId , CreatedDate
, UserId 
, matchid
,IssueType
)
SELECT r.RequestId, r.IssueTypeId,r.CreatedDate
  , r.UserId, rd.MatchId
  , i.IssueTypeName
FROM DBTRANS.bodb02.dbo.TicketVoiding_Request r  WITH(NOLOCK) 
	CROSS APPLY (
          SELECT TOP (1)  CASE WHEN rd.transids LIKE '%IsMainMatch="true"%' THEN rd.MatchId 
												 WHEN r.IssueTypeId IN (13,17,20) THEN NULL 
												 ELSE rd.MatchId END MatchId
          FROM  DBTRANS.bodb02.dbo.TicketVoiding_RequestDetail rd  WITH(NOLOCK) 
          WHERE r.RequestId = rd.RequestId
           ORDER BY rd.Id ASC
		  )rd
    LEFT JOIN DBTRANS.bodb02.dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
WHERE r.IsTest = 0
AND r.CreatedDate >= DATEADD (DAY, -5, @from) AND r.CreatedDate < DATEADD (DAY, +5, @to)

INSERT INTO #temp_Ticket(
	RequestId 
	, matchid
    , TransId  
	, Transdate 
	, statusID 
	, stake 
	, actualrate 
	, actual_stake 
	, winlostdate 
    , Transid_void
	, bettype 
	, betteam 
	, livehomescore 
	, liveawayscore  
	, zzz_status
	, zzz_Transdate
	, REASON
	, Username
	, custid
	, HDP1
	, HDP2
	, CurrencyName
	, odds
)
SELECT t.RequestId, t.Matchid, s.TransId,  b.Transdate 
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.actual_stake 
	, b.winlostdate 
    , z.transid AS Transid_void
	, s.bettype 
	, b.betteam 
	, b.livehomescore 
	, b.liveawayscore
	, z.status AS zzz_status
	, z.transdate AS zzz_transdate
	, t.IssueType AS REASON
	, b.Username
	, b.custid
	, b.HDP1
	, b.HDP2
	, b.CurrencyName
	, b.odds
FROM #temp_transid t
	INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) ON t.RequestId = s.RequestId
	CROSS APPLY (
		SELECT transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, Username, custid, HDP1, HDP2, currencyname, odds
		FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
		UNION 
		SELECT transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, Username, custid, HDP1, HDP2, currencyname, odds
		FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
	)b
	LEFT JOIN bodb02.dbo.zzzbettrans z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
WHERE b.statusID = 102

/*parlay*/
INSERT INTO #temp_Ticket(
	RequestId 
	, matchid
    , TransId  
	, Transdate 
	, statusID 
	, stake 
	, actualrate 
	, winlostdate 
    , Transid_void
	, bettype 
	, betteam 
	, livehomescore 
	, liveawayscore  
	, zzz_status
	, zzz_Transdate
	, REASON
	, IsParlay
	, custid
	, HDP1
	, HDP2
	, odds
)
SELECT t.RequestId, t.Matchid, s.MainTransId,  b.Transdate 
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.winlostdate 
    , z.transid AS Transid_void
	, b.bettype 
	, b.betteam 
	, b.livehomescore 
	, b.liveawayscore
	, z.status AS zzz_status
	, z.transdate AS zzz_transdate
	, t.IssueType AS REASON
	, 1 AS IsParlay
	, b.custid
	, b.HDP1
	, b.HDP2
	, b.odds
FROM #temp_transid t
		INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) ON t.RequestId = s.RequestId
		CROSS APPLY (
			SELECT transdate, statusID, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, custid, HDP1, HDP2, odds
			FROM bodb02.dbo.bettransm b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
			UNION 
			SELECT transdate, statusID, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, custid, HDP1, HDP2, odds
			FROM bodb02.dbo.bettransm14 b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		LEFT JOIN bodb02.dbo.zzzbettransm z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
WHERE b.statusID = 102	

UPDATE S
SET S.Username = B.Username
,S.actual_stake = B.actual_stake
,S.currencyname = B.currencyname
FROM #temp_Ticket S
	CROSS APPLY (
		SELECT transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, Username, custid, HDP1, HDP2, currencyname, odds
		FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
		UNION 
		SELECT  transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, Username, custid, HDP1, HDP2, currencyname, odds
		FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
	)b
WHERE IsParlay =1 


UPDATE	t 
		SET LastVoidedBy = vh.LastVoidedBy
		   ,[Date] = CAST(vh.CreatedDate AS DATE)
	FROM	#temp_Ticket t
		CROSS APPLY (
			SELECT	TOP (1) vh.RequestId, vh.VoidingHistoryId, vh.UserId AS LastVoidedBy, vh.CreatedDate
			FROM	bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
			WHERE	vh.RequestId = t.requestId AND vh.StatusId IN (2,3)
			ORDER BY vh.VoidingHistoryId DESC
		) vh

delete from #temp_Ticket where [Date] not between @from and @to

UPDATE d
SET d.sporttype =   m.sporttype
, d.sportName = m.SportName
, d.home = m.home
, d.away = m.away																				
FROM #temp_Ticket d
CROSS APPLY (																								
		SELECT  matchid, leagueid , h.teamname as home, a.teamname as away, s.SportName, m.sporttype																							
		FROM	bodb02.dbo.match m WITH (NOLOCK)																						
			LEFT JOIN bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
			LEFT JOIN bodb02.dbo.team a with (nolock) on a.teamid = m.awayid																						
			LEFT JOIN bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		WHERE	matchid = d.matchid	
		
		UNION ALL																							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	bodb02.dbo.outright m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			LEFT JOIN bodb02.dbo.team h with (nolock) on h.teamid = m.teamid																						
			LEFT JOIN bodb02.dbo.Sports s with (nolock) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid	
		
		UNION ALL	
		SELECT  matchid, leagueid	, h.teamname as home, a.teamname as away	, s.SportName, m.sporttype																					
		FROM	bodb02.dbo.match14 m WITH (NOLOCK)																						
			LEFT JOIN bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
			LEFT JOIN bodb02.dbo.team a with (nolock) on a.teamid = m.awayid																						
			LEFT JOIN bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		WHERE	matchid = d.matchid																						
																									
		UNION ALL	
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	bodb02.dbo.outright14 m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			LEFT JOIN bodb02.dbo.team h with (nolock) on h.teamid = m.teamid																						
			LEFT JOIN bodb02.dbo.Sports s with (nolock) on s.SportType = L.sporttype																					
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
	) m																								

/**********************************************************RANGE ARCHIVE*************************************************************/
INSERT #temp_transid (RequestId, IssueTypeId , CreatedDate 
, UserId 
, matchid
, IssueType
)
SELECT r.RequestId, r.IssueTypeId,r.CreatedDate
, r.UserId, rd.MatchId
  , i.IssueTypeName 
FROM dbo.TicketVoiding_Request_bk r  WITH(NOLOCK) 
		CROSS APPLY (
          SELECT TOP (1) CASE WHEN rd.transids LIKE '%IsMainMatch="true"%' THEN rd.MatchId 
												 WHEN r.IssueTypeId IN (13,17,20) THEN NULL 
												 ELSE rd.MatchId END MatchId
          FROM  dbo.TicketVoiding_RequestDetail_bk rd  WITH(NOLOCK) 
          WHERE r.RequestId = rd.RequestId
		  ORDER BY rd.Id ASC
          )rd
    LEFT JOIN DBTRANS.bodb02.dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
WHERE r.IsTest = 0
AND NOT EXISTS ( SELECT TOP 1 1 FROM #temp_transid WHERE r.RequestId = RequestId)
AND r.CreatedDate >= DATEADD (DAY, -2, @from) AND r.CreatedDate < DATEADD (DAY, +2, @to)

INSERT INTO #temp_Ticket(
	RequestId 
	, matchid
    , TransId  
	, Transdate 
	, statusID 
	, stake 
	, actualrate 
	, actual_stake 
	, winlostdate 
    , Transid_void
	, bettype 
	, betteam 
	, livehomescore 
	, liveawayscore  
	, zzz_status
	, zzz_Transdate
	, REASON
	, IsArchived
	, custid
	, HDP1
	, HDP2
	, odds
	, currency
)
SELECT t.RequestId, s.Matchid, s.TransId,  b.Transdate 
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.actual_stake 
	, b.winlostdate 
    , z.transid AS Transid_void
	, s.bettype 
	, b.betteam 
	, b.livehomescore 
	, b.liveawayscore
	, z.status AS zzz_status
	, z.transdate AS zzz_transdate
	, t.IssueType AS REASON
	, 1 AS IsArchived
	, b.custid
	, b.HDP1
	, b.HDP2
	, b.odds
	, b.currency
FROM #temp_transid t
		INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId AND s.IsProcessed = 1
		CROSS APPLY (
			SELECT  transdate, statusID, stake, actualrate, actual_stake, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, custid, HDP1, HDP2, currency, odds
			FROM dbo.bettrans_bk b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
        LEFT JOIN dbo.zzzbettrans_bk z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL

UPDATE S
SET s.CurrencyName = e.currency
FROM #temp_Ticket S
	INNER JOIN bodb02.dbo.Exchange e WITH (NOLOCK) ON s.currency = e.ExchangeId
WHERE IsParlay = 0 AND IsArchived = 1

---Update for case MBU T5 not copy zzzbetrans_bk, T6 delete zzzbettrans => miss data 
UPDATE t
SET Transid_void = vt.TransId
FROM #temp_Ticket t
	INNER JOIN dbo.TicketVoiding_VoidedTransaction_bk vt WITH (NOLOCK) ON t.TransId = vt.TransId
WHERE IsArchived = 1
	AND Transid_void IS NULL 
	AND t.statusID = 102 --VOID

/*parlay*/
INSERT INTO #temp_Ticket(
	RequestId 
	, matchid
    , TransId  
	, Transdate 
	, statusID 
	, stake 
	, actualrate 
	, winlostdate 
    , Transid_void
	, bettype 
	, betteam 
	, livehomescore 
	, liveawayscore  
	, zzz_status
	, zzz_Transdate
	, REASON
	, IsArchived
	, IsParlay
	, custid
	, HDP1
	, HDP2
	, odds
)
SELECT t.RequestId, s.Matchid, s.MainTransId,  b.Transdate 
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.winlostdate 
    , z.transid AS Transid_void
	, b.bettype 
	, b.betteam 
	, b.livehomescore 
	, b.liveawayscore
	, z.status AS zzz_status
	, z.transdate AS zzz_transdate
	, t.IssueType AS REASON
	, 1 AS IsArchived
	, 1 AS IsParlay
	, b.custid
	, b.HDP1
	, b.HDP2
	, b.odds
FROM #temp_transid t
		INNER JOIN dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId AND s.IsProcessed = 1
		CROSS APPLY (
			SELECT transdate, statusID, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, custid, HDP1, HDP2, odds
			FROM dbo.bettransm b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
			UNION 
			SELECT transdate, statusID, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, custid, HDP1, HDP2, odds
			FROM bodb02.dbo.bettransm14 b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		LEFT JOIN dbo.zzzbettrans_bk z WITH (NOLOCK) ON z.transid = s.TransId AND z.VoidingHistoryId IS NOT NULL

UPDATE S
SET S.actual_stake = B.actual_stake
   ,s.currency = b.currency
FROM #temp_Ticket S
	CROSS APPLY (
		SELECT actual_stake, currency
		FROM .dbo.bettrans_bk b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId 
	)b
WHERE IsParlay = 1 AND IsArchived =1

UPDATE d
SET d.sporttype =   m.sporttype
, d.sportName = m.SportName
, d.home = m.home
, d.away = m.away
FROM #temp_Ticket d
CROSS APPLY (																								
		SELECT	matchid, leagueid, h.teamname as home, a.teamname as away, s.SportName, m.sporttype																						
		FROM	dbo.match_bk m WITH (NOLOCK)																						
			LEFT JOIN bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
			LEFT JOIN bodb02.dbo.team a with (nolock) on a.teamid = m.awayid																						
			LEFT JOIN bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		WHERE	matchid = d.matchid																						
																									
		UNION ALL							
		SELECT  orid, l.leagueid , h.teamname as home, NULL as away, s.SportName, l.sporttype																							
		FROM	dbo.outright_bk m WITH (NOLOCK)	
			INNER JOIN bodb02.dbo.League l WITH (NOLOCK) ON m.leagueid = l.leagueid	
			LEFT JOIN bodb02.dbo.team h with (nolock) on h.teamid = m.teamid																						
			LEFT JOIN bodb02.dbo.Sports s with (nolock) on s.SportType = L.sporttype																					
		WHERE	orid = d.matchid
		UNION ALL																							
		SELECT  matchid, League3rdId , h.teamname as home, a.teamname as away, s.SportName, m.sporttype																							
		FROM	dbo.Match3rd_BK m WITH (NOLOCK)																						
			LEFT JOIN bodb02.dbo.team3rd h WITH (NOLOCK) on h.team3rdid = m.homeid																						
			LEFT JOIN bodb02.dbo.team3rd a WITH (NOLOCK) on a.team3rdid = m.awayid																						
			LEFT JOIN bodb02.dbo.Sports s WITH (NOLOCK) on s.SportType = m.sporttype																						
		WHERE	Match3rdId = d.matchid
	) m																								

UPDATE	t 
SET LastVoidedBy = vh.LastVoidedBy
	,[Date] = CAST(vh.CreatedDate AS DATE)
	FROM	#temp_Ticket t
		CROSS APPLY (
			SELECT	TOP (1) vh.RequestId, vh.VoidingHistoryId, vh.UserId AS LastVoidedBy, vh.CreatedDate
			FROM dbo.TicketVoiding_VoidingHistory_bk vh WITH(NOLOCK)
			WHERE vh.RequestId = t.requestId AND vh.StatusId IN (2,3)
			ORDER BY vh.VoidingHistoryId DESC
		) vh

		
/*************************************************************************************************************************************
**************************************************************************************************************************************/
SELECT	'TVS' AS 'TVS/SD?', ms.Date AS DATE
, CASE WHEN s.IsDeposit = 1 THEN 'L' ELSE 'C' END AS SITE
, ms.SportName AS SPORTS
, ms.matchid AS MATCHID
, c.Username AS ACCOUNT
, b.typenamee AS BETTYPE
, ms.betteam AS BET
, ms.odds AS ODDS
, ms.currencyname AS CUR
, ms.actual_stake AS AMOUNT
, ms.home + ' -vs- ' + ms.away AS EVENT
, ms.HDP1, ms.HDP2
, CAST(ms.LiveHomeScore AS VARCHAR(10)) + '-' + CAST(ms.LiveAwayScore AS VARCHAR(10)) AS SCORE
, v.Username AS CREATOR
, ms.transid AS REFNO
, ms.zzz_status AS STATUS
, ms.transdate AS BETTIME
, ms.zzz_Transdate AS DELTIME
, ms.REASON
, ms.RequestId
, ms.IsParlay, ms.IsArchived
FROM #temp_Ticket ms WITH (NOLOCK)																									
    INNER JOIN bodb02.dbo.bettype b WITH(NOLOCK) ON ms.bettype = b.typeid
    INNER JOIN bodb02.dbo.vw_Customer c WITH(NOLOCK) ON ms.custid = c.custid
    INNER JOIN bodb02.dbo.vw_Customer v WITH(NOLOCK) ON ms.LastVoidedBy = v.custid
	INNER JOIN bodb02.dbo.Site s WITH(NOLOCK) ON c.site = s.site
WHERE [Date]  >= @from and [Date] < @to
 AND zzz_status is not null
ORDER BY ms.Date ASC 

DROP TABLE #temp_transid
DROP TABLE #temp_Ticket
