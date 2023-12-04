/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/

USE bodb_archive
GO

DECLARE @from datetime, @to datetime ,@RequestInfoGetCalcTimes VARBINARY(MAX) = NULL																									
SET @from = '2023-09-01'																									
SET @to = '2023-10-01'																									
																									
																								
CREATE TABLE #temp_transid (
 Winlostdate SMALLDATETIME
,Matchid INT
,sporttype tinyint
, sportName nVARCHAR(100)
, home nvarchar(200)
, away varchar(200)
, leaguename varchar(1000)
, LeagueGroup varchar(200)
, Bet_cnt INT 
, MemberTO_RM MONEY
, House_TO_RM MONEY
, MessageContent varchar(max)
, RequestId INT
, FromTimeUI DATETIME
, ToTimeUI DATETIME
, IssueType varchar(200)
, SubIssueType varchar(200)
, UserId			INT
, CreatedDate	DATETIME
, MistakenBy		NVARCHAR(200)
, DecidedBy		NVARCHAR(200)
, CheckedBy		INT
, LastVoidedBy	INT
, Action_Req NVARCHAR(50)
, TotalTicket INT
, Min_Trans BIGINT
, Max_Trans BIGINT
, Min_TransDate DATETIME
, Max_TransDate DATETIME
, Liveindicator NVARCHAR(200) 
, IssueTypeId INT
, SubIssueTypeId INT
, TotalTicket_Parlay INT
, Bet_cnt_Parlay INT 
, MessageId INT
, ListBettype VARCHAR(MAX)
, ListBetteam VARCHAR(MAX)
, ListScore VARCHAR(MAX)
, IsHasSettled BIT
)

CREATE TABLE #temp_RequestId_GetList (
	RequestId INT
    , IsFinish BIT
)

CREATE TABLE #temp_Ticket (
	RequestId INT
	,MatchId INT
    , TransId	  BIGINT
	, Transdate DATETIME
	, liveindicator BIT 
	, statusID TINYINT
	, stake MONEY
	, actualrate FLOAT
	, tpositiontaking SMALLMONEY
	, winlostdate SMALLDATETIME
	, bettype SMALLINT
	, betteam NVARCHAR(10)
	, livehomescore SMALLINT
	, liveawayscore SMALLINT 
    , Transid_void BIGINT

)
DECLARE @RequestId INT, @ListBettype VARCHAR(MAX) = '', @ListBetteam VARCHAR(MAX) ='', @ListScore VARCHAR(MAX) = ''

/**********************************************************RANGE ACTIVE*************************************************************/

INSERT #temp_transid (RequestId, IssueTypeId ,SubIssueTypeId, CreatedDate , FromTimeUI
, ToTimeUI
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
--AND r.IssueTypeId IN (11,13)


INSERT INTO #temp_Ticket(
	RequestId 
	, matchid
    , TransId  
	, Transdate 
	, liveindicator  
	, statusID 
	, stake 
	, actualrate 
	, tpositiontaking 
	, winlostdate 
    ,Transid_void
	, bettype 
	, betteam 
	, livehomescore 
	, liveawayscore  

)
SELECT t.RequestId, t.Matchid, s.TransId,  b.Transdate 
	, b.liveindicator  
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.tpositiontaking 
	, b.winlostdate 
    , z.transid AS Transid_void
	, s.bettype 
	, b.betteam 
	, b.livehomescore 
	, b.liveawayscore  
FROM #temp_transid t
	INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) ON t.RequestId = s.RequestId
	CROSS APPLY (
		SELECT liveindicator, transdate, statusID, stake, actualrate, tpositiontaking, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore
		FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
		UNION 
		SELECT liveindicator, transdate, statusID, stake, actualrate, tpositiontaking, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore
		FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
	)b
	LEFT JOIN bodb02.dbo.zzzbettrans z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
    
UPDATE t
SET t.TotalTicket = kq.TotalTicket
,t.Min_Trans = kq.Min_Trans
,t.Max_Trans = kq.Max_Trans
,t.Min_TransDate = kq.Min_TransDate
,t.Max_TransDate = kq.Max_TransDate
,t.Liveindicator = CASE WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt > 0 THEN 'Both'
						WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt = 0 THEN 'Liveball'
						WHEN kq.Live_cnt = 0 AND kq.NonLive_cnt > 0 THEN 'Deadball'
					END
,t.Bet_cnt = kq.Bet_cnt
,t.MemberTO_RM = kq.MemberTO_RM
,t.House_TO_RM = kq.House_TO_RM
,t.winlostdate = kq.winlostdate
,t.IsHasSettled = kq.IsHasSettled
FROM #temp_transid t
INNER JOIN (
	 SELECT t.RequestId
		,b.MatchId
		,MIN(b.winlostdate) AS winlostdate
		,COUNT(b.TransId) AS TotalTicket
		,MIN(b.TransId) AS Min_Trans
		,MAX(b.TransId) AS Max_Trans
		,MIN(b.transdate) AS Min_TransDate
		,MAX(b.transdate) AS Max_TransDate
		,COUNT(CASE WHEN b.liveindicator = 1 THEN b.liveindicator ELSE NULL END) AS Live_cnt 
		,COUNT(CASE WHEN b.liveindicator = 0 THEN b.liveindicator ELSE NULL END) AS NonLive_cnt
        ,COUNT(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL /*AND s.IsProcessed IS NOT NULL*/ THEN b.Transid_void ELSE NULL END) AS Bet_cnt	
		,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL /*AND s.IsProcessed IS NOT NULL*/  THEN cast ((b.stake * b.actualrate) as money) ELSE NULL END) AS MemberTO_RM
		,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL /*AND s.IsProcessed IS NOT NULL*/  THEN cast( ((1-tpositiontaking)* b.stake * actualrate) as money) ELSE NULL END) AS House_TO_RM	
		,MAX(CASE WHEN b.statusid IN (111,112,113) THEN 1 ELSE 0 END) AS IsHasSettled
	FROM #temp_transid t
		INNER JOIN #temp_Ticket b ON t.RequestId = b.RequestId
	GROUP BY t.RequestId, b.MatchId
)kq ON t.RequestId = kq.RequestId 
	

/*parlay*/
UPDATE t
SET t.TotalTicket_Parlay = kq.TotalTicket_Parlay
,t.Bet_cnt_Parlay = kq.Bet_cnt_Parlay
,t.winlostdate = kq.winlostdate
,t.IsHasSettled = kq.IsHasSettled
FROM #temp_transid t
INNER JOIN (
	 SELECT t.RequestId
		,s.MatchId
		,b.winlostdate
		,COUNT(s.TransId) AS TotalTicket_Parlay
        ,COUNT(CASE WHEN b.statusid = 102 AND z.transid IS NOT NULL AND s.IsProcessed IS NOT NULL THEN s.TransId ELSE NULL END ) AS Bet_cnt_Parlay	
		,MAX(CASE WHEN b.statusid IN (111,112,113) THEN 1 ELSE 0 END) AS IsHasSettled
	FROM #temp_transid t
		INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) ON t.RequestId = s.RequestId
		CROSS APPLY (
			SELECT statusID, winlostdate, TransId
			FROM bodb02.dbo.bettransm b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
			UNION 
			SELECT statusID, winlostdate, TransId
			FROM bodb02.dbo.bettransm14 b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		LEFT JOIN bodb02.dbo.zzzbettransm z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
	GROUP BY t.RequestId, s.MatchId, b.winlostdate
)kq ON t.RequestId = kq.RequestId

UPDATE	t 
		SET LastVoidedBy = vh.LastVoidedBy
			,MessageId = vh.MessageId
	FROM	#temp_transid t
		CROSS APPLY (
			SELECT	TOP (1) vh.RequestId, vh.VoidingHistoryId, vh.UserId AS LastVoidedBy, vh.MessageId
			FROM	bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
			WHERE	vh.RequestId = t.requestId AND vh.StatusId IN (2,3)
			ORDER BY vh.VoidingHistoryId DESC
		) vh


UPDATE d
SET d.sporttype =   m.sporttype
, d.sportName = m.SportName
, d.home = m.home
, d.away = m.away
, d.leaguename = l.leaguename
, d.LeagueGroup = case when isnull(l.[Group],'')=''  then 'Others' else l.[Group] end																					
FROM #temp_transid d
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
	) m																								
INNER JOIN bodb02.dbo.League l WITH (NOLOCK)																								
	ON m.leagueid = l.leagueid	


/**********************************************************RANGE ARCHIVE*************************************************************/
INSERT #temp_transid (RequestId, IssueTypeId ,SubIssueTypeId, CreatedDate , FromTimeUI
, ToTimeUI
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
	RequestId 
	, matchid
    , TransId  
	, Transdate 
	, liveindicator  
	, statusID 
	, stake 
	, actualrate 
	, tpositiontaking 
	, winlostdate 
    ,Transid_void
    , bettype 
	, betteam 
	, livehomescore 
	, liveawayscore  

)
SELECT t.RequestId, t.Matchid, s.TransId,  b.Transdate 
	, b.liveindicator  
	, b.statusID 
	, b.stake 
	, b.actualrate 
	, b.tpositiontaking 
	, b.winlostdate 
	 , z.transid AS Transid_void
    , b.bettype 
	, b.betteam 
	, b.livehomescore 
	, b.liveawayscore  
FROM #temp_transid t
		INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId 
		CROSS APPLY (
			SELECT liveindicator, transdate, statusID, stake, actualrate, tpositiontaking, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore
			FROM dbo.bettrans_bk b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
        LEFT JOIN dbo.zzzbettrans_bk z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
    

UPDATE t
SET t.TotalTicket = kq.TotalTicket
,t.Min_Trans = kq.Min_Trans
,t.Max_Trans = kq.Max_Trans
,t.Min_TransDate = kq.Min_TransDate
,t.Max_TransDate = kq.Max_TransDate
,t.Liveindicator = CASE WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt > 0 THEN 'Both'
						WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt = 0 THEN 'Liveball'
						WHEN kq.Live_cnt = 0 AND kq.NonLive_cnt > 0 THEN 'Deadball'
					END
,t.Bet_cnt = kq.Bet_cnt
,t.MemberTO_RM = kq.MemberTO_RM
,t.House_TO_RM = kq.House_TO_RM
,t.winlostdate = kq.winlostdate
,t.IsHasSettled = kq.IsHasSettled
FROM #temp_transid t
INNER JOIN (
	 SELECT t.RequestId
		,b.MatchId
		,MIN(b.winlostdate) AS winlostdate
		,COUNT(b.TransId) AS TotalTicket
		,MIN(b.TransId) AS Min_Trans
		,MAX(b.TransId) AS Max_Trans
		,MIN(b.transdate) AS Min_TransDate
		,MAX(b.transdate) AS Max_TransDate
		,COUNT(CASE WHEN b.liveindicator = 1 THEN b.liveindicator ELSE NULL END) AS Live_cnt 
		,COUNT(CASE WHEN b.liveindicator = 0 THEN b.liveindicator ELSE NULL END) AS NonLive_cnt
        ,COUNT(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL /*AND s.IsProcessed IS NOT NULL*/ THEN b.Transid_void ELSE NULL END) AS Bet_cnt	
		,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL /*AND s.IsProcessed IS NOT NULL*/  THEN cast ((b.stake * b.actualrate) as money) ELSE NULL END) AS MemberTO_RM
		,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL /*AND s.IsProcessed IS NOT NULL*/  THEN cast( ((1-tpositiontaking)* b.stake * actualrate) as money) ELSE NULL END) AS House_TO_RM	
		,MAX(CASE WHEN b.statusid IN (111,112,113) THEN 1 ELSE 0 END) AS IsHasSettled
	FROM #temp_transid t
		INNER JOIN #temp_Ticket b ON t.RequestId = b.RequestId
	GROUP BY t.RequestId, b.MatchId
)kq ON t.RequestId = kq.RequestId


/*parlay*/
UPDATE t
SET t.TotalTicket_Parlay = kq.TotalTicket_Parlay
,t.Bet_cnt_Parlay = kq.Bet_cnt_Parlay
,t.winlostdate = kq.winlostdate
,t.IsHasSettled = kq.IsHasSettled
FROM #temp_transid t
INNER JOIN (
	 SELECT t.RequestId
		,s.MatchId
		,b.winlostdate
		,COUNT(s.TransId) AS TotalTicket_Parlay
        ,COUNT(CASE WHEN b.statusid = 102 AND z.transid IS NOT NULL AND s.IsProcessed IS NOT NULL THEN s.TransId ELSE NULL END ) AS Bet_cnt_Parlay	
		,MAX(CASE WHEN b.statusid IN (111,112,113) THEN 1 ELSE 0 END) AS IsHasSettled
	FROM #temp_transid t
		INNER JOIN dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId
		CROSS APPLY (
			SELECT statusID, winlostdate, TransId
			FROM dbo.bettransm b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		LEFT JOIN dbo.zzzbettransm_bk z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
	GROUP BY t.RequestId, s.MatchId, b.winlostdate
)kq ON t.RequestId = kq.RequestId


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
	) m																								
INNER JOIN bodb02.dbo.League l WITH (NOLOCK)																								
	ON m.leagueid = l.leagueid	

UPDATE	t 
		SET LastVoidedBy = vh.LastVoidedBy
			,MessageId = vh.MessageId
	FROM	#temp_transid t
		CROSS APPLY (
			SELECT	TOP (1) vh.RequestId, vh.VoidingHistoryId, vh.UserId AS LastVoidedBy, vh.MessageId
			FROM dbo.TicketVoiding_VoidingHistory_bk vh WITH(NOLOCK)
			WHERE vh.RequestId = t.requestId AND vh.StatusId IN (2,3)
			ORDER BY vh.VoidingHistoryId DESC
		) vh


/*************************************************************************************************************************************
**************************************************************************************************************************************/
UPDATE	t 
		SET MessageContent = CASE WHEN ms.MessageId IS NOT NULL THEN ms.Content_en
								  WHEN ms1.MessageId IS NOT NULL THEN ms1.Content_en
								  ELSE NULL END
FROM	#temp_transid t
	LEFT JOIN  DBMSG.bodb_Message.dbo.[Msg] ms WITH (NOLOCK) ON t.MessageId = ms.MessageId
	LEFT JOIN  DBMSG.bodb_Message_Archive.dbo.[Msg_Archive] ms1 WITH (NOLOCK) ON t.MessageId = ms1.MessageId																						


INSERT INTO #temp_RequestId_GetList (RequestId)
SELECT DISTINCT RequestId
FROM #temp_transid


WHILE(1=1)
BEGIN
	SET @ListBettype = ''
	SET @ListBetteam = ''
	SET @ListScore = ''
	SET @RequestId = 0


	UPDATE TOP (1) m SET m.IsFinish = 1, @RequestId = m.RequestId
	FROM #temp_RequestId_GetList m 
	WHERE m.IsFinish IS NULL
	IF @@ROWCOUNT = 0 BREAK	


	SET @ListBettype = ISNULL(STUFF((SELECT DISTINCT ', ' + CAST(b.typenamee AS VARCHAR(100))
										FROM #temp_Ticket AS v
										INNER JOIN DBTRANS.bodb02.dbo.bettype b WITH(NOLOCK) ON v.bettype = b.typeid
										WHERE v.RequestId = @RequestId 
										FOR XML PATH('')), 1, 1, '')
										, '')

	SET @ListBetteam = ISNULL(STUFF((SELECT DISTINCT ', ' + CAST(v.betteam AS VARCHAR(100))
										FROM #temp_Ticket AS v
										WHERE v.RequestId = @RequestId
										FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 2, '')
										, '')

	SET @ListScore = ISNULL(STUFF((SELECT DISTINCT ', ' + CAST(v.livehomescore AS VARCHAR(10)) + '-' + CAST(v.liveawayscore AS VARCHAR(10))
									FROM #temp_Ticket AS v
									WHERE v.RequestId = @RequestId
									FOR XML PATH(''), TYPE).value('.', 'VARCHAR(MAX)'), 1, 2, '')
									, '')

	UPDATE v
	SET v.ListBettype = @ListBettype
	, v.ListBetteam = @ListBetteam
	, v.ListScore = @ListScore
	FROM #temp_transid v
	WHERE  v.RequestId = @RequestId
END


/********CASE TICKET CREATE MANY REQUEST***************************************************/
UPDATE t
SET Bet_cnt = NULL, t.Bet_cnt_Parlay = NULL, MemberTO_RM =NULL, House_TO_RM= NULL, MessageContent = NULL
FROM #temp_transid t
WHERE ISNULL(LastVoidedBy,0) = 0 

/*************************************************************************************************************************************
**************************************************************************************************************************************/
SELECT DISTINCT 
		CASE WHEN IssueTypeId IN (11,15,13)  THEN 'No' 
			 WHEN IssueTypeId NOT IN (11,15,13) AND ISNULL(ms.Bet_cnt,0) > 0 THEN 'Yes' 
			 ELSE 'No' END IsMonthly
	,'TVS' AS 'TVS/SD?'
	, CASE WHEN IssueTypeId IN (13) THEN NULL ELSE ms.winlostdate END as winlostdate
	, YEAR(ms.winlostdate) AS YEAR_winlostdate
	, MONTH(ms.winlostdate) AS MONTH_winlostdate
	, CASE WHEN IssueTypeId IN (11,13,18) THEN SubIssueType ELSE IssueType END AS Reason, ms.matchid, ms.sporttype, ms.SportName, ms.home, ms.away, ms.leaguename,ms.LeagueGroup
    , ms.Bet_cnt, ms.MemberTO_RM, ms.House_TO_RM	
    , a.ActionName
	, 'Null' as Function_SDName
	, ms.RequestId, ms.TotalTicket, ms.TotalTicket_Parlay, ms.Bet_cnt_Parlay
    , ms.IssueType, ms.SubIssueType
	, c.Username AS CreatedBy,ms.CreatedDate
    , ISNULL(DATEDIFF(mi, ms.Max_TransDate, ms.CreatedDate),0)  AS Duration
	, ms.FromTimeUI, ms.ToTimeUI
	, ms.MistakenBy, ms.DecidedBy, v.Username AS PerformanceBy
    , CASE WHEN (ms.Bet_cnt > 0 OR ms.Bet_cnt_Parlay >0) AND ms.Action_Req NOT IN ( 2,3,5) THEN 'Auto Void'
		   WHEN (ms.Bet_cnt > 0 OR ms.Bet_cnt_Parlay >0) AND ms.Action_Req IN ( 2,3,5) THEN 'Manual Void'
	       ELSE 'No Void'
		END AS 'Auto Void?'
	, ms.Min_Trans , ms.Max_Trans , ms.Min_TransDate , ms.Max_TransDate , ms.Liveindicator
	, ms.ListBettype, ms.ListBetteam, ms.ListScore, '' Calc_HTTime,'' Calc_FTTime
	, ms.MessageContent
	, CASE WHEN ms.IsHasSettled = 1 THEN 'Yes' ELSE 'No' END AS 'Has Void Settled?'
FROM #temp_transid ms
	INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_Action a WITH(NOLOCK) 
		ON ms.Action_Req = a.ActionId
	LEFT JOIN bodb02.dbo.vw_Customer c WITH(NOLOCK)
		ON ms.UserId = c.CustId
	LEFT JOIN bodb02.dbo.vw_Customer v WITH(NOLOCK)
		ON ms.LastVoidedBy = v.CustId
ORDER BY ms.CreatedDate ASC, ms.RequestId ASC

	--Support get calculate time => STEP 3.1 & 3.2
	SET @RequestInfoGetCalcTimes = COMPRESS((SELECT 
		  Sporttype AS 's'
		  ,MatchId AS 'mid'
	FROM #temp_transid
	WHERE IssueTypeId IN (11,15) AND matchid <> 29
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfoGetCalcTimes, 1) AS RequestInfoGetCalcTimes
    
DROP TABLE #temp_transid
DROP TABLE #temp_Ticket
DROP TABLE #temp_RequestId_GetList