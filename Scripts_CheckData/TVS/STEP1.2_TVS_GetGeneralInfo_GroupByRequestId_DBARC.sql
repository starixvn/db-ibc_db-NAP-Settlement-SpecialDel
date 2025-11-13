/*<info serverAlias="DBARC-bodb_archive" executers="" viewers="" isFunction="0"></info>*/

USE bodb_archive
GO

DECLARE @from datetime, @to datetime ,@RequestInfoGetCalcTimes VARBINARY(MAX) = NULL																									
SET @from = '2025-10-22'																									
SET @to = '2025-10-24'																									
																									
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
, Min_Trans_SubParlay BIGINT
, Max_Trans_SubParlay BIGINT
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
    , MainTransId BIGINT
	, Transdate DATETIME
	, liveindicator BIT 
	, stake MONEY
	, actualrate FLOAT
	, tpositiontaking SMALLMONEY
	, winlostdate SMALLDATETIME
	, bettype SMALLINT
	, betteam NVARCHAR(10)
	, Subbetteam NVARCHAR(10)
    , livehomescore SMALLINT
	, liveawayscore SMALLINT 
    , Transid_void BIGINT
	, IsArchived BIT DEFAULT(0)
	, IsParlay BIT DEFAULT(0) 
    , selection INT 
    , zzz_status NVARCHAR(100)
    , statusid INT
    , refno BIGINT
	, stake_tmp MONEY
	, IsMissBetParlayDetail BIT DEFAULT(0)
)
DECLARE @RequestId INT, @ListBettype VARCHAR(MAX) = '', @ListBetteam VARCHAR(MAX) ='', @ListScore VARCHAR(MAX) = ''

/**********************************************************RANGE ACTIVE*************************************************************/
BEGIN
	INSERT #temp_transid (RequestId, IssueTypeId ,SubIssueTypeId, CreatedDate , FromTimeUI
	, ToTimeUI
	, MistakenBy , DecidedBy , UserId 
	, Action_Req 
	, matchid
	, IssueType
	, SubIssueType
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
   --and r.requestid = 159065
    
	/*parlay*/
	INSERT INTO #temp_Ticket(
		RequestId 
		, matchid
		, TransId  
		, MainTransId
        , Transdate 
		, liveindicator  
		, actualrate 
		, winlostdate 
		, Transid_void
		, bettype 
		, Subbetteam
		, livehomescore 
		, liveawayscore  
		, IsParlay
        , zzz_status
        , statusid
	)
	SELECT t.RequestId, t.Matchid, s.TransId, s.MainTransId,  b.Transdate 
		, b.liveindicator  
		, b.actualrate 
		, b.winlostdate 
		, z.transid AS Transid_void
		, b.bettype 
		, b.betteam AS Subbetteam
		, b.livehomescore 
		, b.liveawayscore  
		, 1 AS IsParlay
        , z.status AS zzz_status
        , b.statusid
	FROM #temp_transid t
		INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_RequestDetailTicket_SubParlay s WITH (NOLOCK) ON t.RequestId = s.RequestId
		CROSS APPLY (
			SELECT liveindicator, transdate, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, statusid
			FROM bodb02.dbo.bettransm b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
			UNION 
			SELECT liveindicator, transdate, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, statusid
			FROM bodb02.dbo.bettransm14 b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		LEFT JOIN bodb02.dbo.zzzbettransm z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
    
    INSERT INTO #temp_Ticket(
		RequestId 
		, matchid
		, TransId  
		, MainTransId
        , Transid_void
        , zzz_status
	)
	SELECT t.RequestId, t.Matchid, s.TransId, s.TransId AS MainTransId
    	, z.transid AS Transid_void, z.status AS zzz_status
	FROM #temp_transid t
		INNER JOIN DBTRANS.bodb02.dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK) ON t.RequestId = s.RequestId
		LEFT JOIN bodb02.dbo.zzzbettrans z WITH (NOLOCK) ON z.transid = s.TransId AND z.VoidingHistoryId IS NOT NULL

    UPDATE t
	SET    Transdate = CASE WHEN t.IsParlay = 0 THEN b.Transdate ELSE t.Transdate END
        , liveindicator  = CASE WHEN t.IsParlay = 0 THEN b.liveindicator ELSE t.liveindicator END
        , stake = b.stake 
        , actualrate = b.actualrate  
        , tpositiontaking = b.tpositiontaking 
        , winlostdate = CASE WHEN t.IsParlay = 0 THEN b.winlostdate ELSE t.winlostdate END
        , bettype  = CASE WHEN t.IsParlay = 0 THEN b.bettype ELSE t.bettype END
        , betteam = b.betteam
        , Subbetteam = b.betteam
        , livehomescore  = CASE WHEN t.IsParlay = 0 THEN b.livehomescore ELSE t.livehomescore END
        , liveawayscore  = CASE WHEN t.IsParlay = 0 THEN b.liveawayscore ELSE t.liveawayscore END
        , selection = CASE WHEN t.IsParlay = 1 AND ISNULL(b.oddsspread,0) <> 3 THEN b.hdp2 --Mix/System parlay
						   WHEN t.IsParlay = 1 AND ISNULL(b.oddsspread,0) = 3 THEN b.betid --Hybrid parlay
						   ELSE 0 END
        , statusid = CASE WHEN t.IsParlay = 0 THEN b.statusid ELSE t.statusid END
        , refno = b.refno
    FROM #temp_Ticket t
		CROSS APPLY (
			SELECT liveindicator, transdate, stake, actualrate, tpositiontaking, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, hdp2, statusid, refno, oddsspread, betid
			FROM bodb02.dbo.bettrans b WITH (NOLOCK) 
			WHERE b.TransId = t.MainTransId
			UNION 
			SELECT liveindicator, transdate, stake, actualrate, tpositiontaking, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, hdp2, statusid, refno, oddsspread, betid
			FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
			WHERE b.TransId = t.MainTransId
		)b
         
IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE isparlay = 1)
BEGIN
	IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE betteam = '1')
    BEGIN
		UPDATE t
		SET t.stake_tmp = CAST (t.stake/t.selection AS FLOAT)
		FROM #temp_Ticket t
		WHERE isparlay = 1 AND betteam = '1' AND t.statusID = 102
	END
		 
	IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE betteam <> '1')
	BEGIN
		;WITH CTE_Sumstake AS(
		SELECT SUM((bp.stake / SUBSTRING(CAST(bp.Serial AS VARCHAR(20)), 2, 2))) AS Sumstake
				,bp.Refno
				,bp.TransId --Sub ticket
		FROM DBTRANS.bodb02.dbo.BetParlayDetail bp (NOLOCK) 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket t
										WHERE t.IsParlay = 1 AND t.betteam <> '1' AND bp.refno = t.refno AND bp.transid = t.transid AND t.statusID = 102)
		GROUP BY Refno, TransId
		)
		UPDATE t
		SET t.stake_tmp = cte.Sumstake
		FROM #temp_Ticket t
			INNER JOIN CTE_Sumstake cte ON t.refno = cte.refno AND t.transid = cte.transid
		WHERE IsParlay = 1 AND betteam <> '1' AND t.statusID = 102
		 
		--For main parlay status: Reject, sub parlay: VOID, table : BetParlayDetail (no data).
		IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE isparlay = 1 AND betteam <> '1' AND statusID = 102 AND stake_tmp IS NULL)
		BEGIN
		UPDATE t
			SET t.stake_tmp = CAST (t.stake/t.selection AS FLOAT), IsMissBetParlayDetail = 1
			FROM #temp_Ticket t
			WHERE IsParlay = 1 AND betteam <> '1' AND t.statusID = 102 AND stake_tmp IS NULL
		END
	END
	UPDATE #temp_Ticket
	SET stake = stake_tmp
	WHERE isparlay = 1  AND stake_tmp IS NOT NULL
END
     
	UPDATE t
	SET t.TotalTicket = kq.TotalTicket
	,t.TotalTicket_Parlay = kq.TotalTicket_Parlay
    ,t.Min_Trans = kq.Min_Trans
	,t.Max_Trans = kq.Max_Trans
    ,t.Min_Trans_SubParlay = kq.Min_Trans_SubParlay
	,t.Max_Trans_SubParlay = kq.Max_Trans_SubParlay
	,t.Min_TransDate = kq.Min_TransDate
	,t.Max_TransDate = kq.Max_TransDate
	,t.Liveindicator = CASE WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt > 0 THEN 'Both'
							WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt = 0 THEN 'Liveball'
							WHEN kq.Live_cnt = 0 AND kq.NonLive_cnt > 0 THEN 'Deadball'
						END
	,t.Bet_cnt = kq.Bet_cnt
    ,t.Bet_cnt_Parlay = kq.Bet_cnt_Parlay
	,t.MemberTO_RM = kq.MemberTO_RM
	,t.House_TO_RM = kq.House_TO_RM
	,t.winlostdate = kq.winlostdate
	,t.IsHasSettled = kq.IsHasSettled
    FROM #temp_transid t
	INNER JOIN (
		 SELECT t.RequestId
			 ,b.MatchId
			 ,MIN(b.winlostdate) AS winlostdate
			 ,COUNT(CASE WHEN b.IsParlay = 0 THEN b.TransId ELSE NULL END) AS TotalTicket
			 ,COUNT(CASE WHEN b.IsParlay = 1 THEN b.TransId ELSE NULL END) AS TotalTicket_Parlay
             ,MIN(b.TransId) AS Min_Trans
			 ,MAX(b.TransId) AS Max_Trans
			 ,MIN(CASE WHEN b.IsParlay = 1 THEN b.TransId ELSE NULL END) AS Min_Trans_SubParlay
			 ,MAX(CASE WHEN b.IsParlay = 1 THEN b.TransId ELSE NULL END) AS Max_Trans_SubParlay
             ,MIN(b.transdate) AS Min_TransDate --single/main/sub
			 ,MAX(b.transdate) AS Max_TransDate --single/main/sub
			 ,COUNT(CASE WHEN b.liveindicator = 1 THEN b.liveindicator ELSE NULL END) AS Live_cnt 
			 ,COUNT(CASE WHEN b.liveindicator = 0 THEN b.liveindicator ELSE NULL END) AS NonLive_cnt
			 ,COUNT(CASE WHEN b.statusid = 102 AND b.IsParlay = 0 AND b.Transid_void IS NOT NULL THEN b.Transid_void ELSE NULL END) AS Bet_cnt	
             ,COUNT(CASE WHEN b.statusid = 102 AND b.IsParlay = 1 AND b.Transid_void IS NOT NULL THEN b.Transid_void ELSE NULL END) AS Bet_cnt_Parlay	
			 ,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL THEN cast ((b.stake * b.actualrate) as money) ELSE NULL END) AS MemberTO_RM
			 ,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL THEN cast( ((1-tpositiontaking)* b.stake * actualrate) as money) ELSE NULL END) AS House_TO_RM	
			 ,MAX(CASE WHEN b.zzz_status IN ('LOSE','WON','DRAW') THEN 1 ELSE 0 END) AS IsHasSettled
		FROM #temp_transid t
			INNER JOIN #temp_Ticket b ON t.RequestId = b.RequestId
		GROUP BY t.RequestId, b.MatchId
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
			) m																								
			INNER JOIN bodb02.dbo.League3rd l WITH (NOLOCK)																								
				ON m.League3rdId = l.League3rdId																							
		WHERE l.isTest = 0	
	END
END

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
--and r.requestid = 159065

TRUNCATE TABLE #temp_Ticket 
INSERT INTO #temp_Ticket(
		RequestId 
		, matchid
		, TransId  
		, MainTransId
        , Transdate 
		, liveindicator  
		, actualrate 
		, winlostdate 
		, Transid_void
		, bettype 
		, Subbetteam
		, livehomescore 
		, liveawayscore  
		, IsParlay
        , zzz_status
        , statusid
	)
	SELECT t.RequestId, t.Matchid, s.TransId, s.MainTransId,  b.Transdate 
		, b.liveindicator  
		, b.actualrate 
		, b.winlostdate 
		, z.transid AS Transid_void
		, b.bettype 
		, b.betteam AS Subbetteam
		, b.livehomescore 
		, b.liveawayscore  
		, 1 AS IsParlay
        , z.status AS zzz_status
        , b.statusid
	FROM #temp_transid t
		INNER JOIN dbo.TicketVoiding_RequestDetailTicket_SubParlay_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId
		CROSS APPLY (
			SELECT liveindicator, transdate, stake, actualrate, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, statusid
			FROM dbo.bettransm b WITH (NOLOCK) 
			WHERE b.TransId = s.TransId
		)b
		LEFT JOIN dbo.zzzbettransm_bk z WITH (NOLOCK) ON z.transid = b.TransId AND z.VoidingHistoryId IS NOT NULL
        
	INSERT INTO #temp_Ticket(
		RequestId 
		, matchid
		, TransId  
		, MainTransId
        , Transid_void
        , zzz_status
	)
	SELECT t.RequestId, t.Matchid, s.TransId, s.TransId AS MainTransId
    	, z.transid AS Transid_void, z.status AS zzz_status
	FROM #temp_transid t
		INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId
		LEFT JOIN zzzbettrans_bk z WITH (NOLOCK) ON z.transid = s.TransId AND z.VoidingHistoryId IS NOT NULL

	UPDATE t
	SET    Transdate = CASE WHEN t.IsParlay = 0 THEN b.Transdate ELSE t.Transdate END
        , liveindicator  = CASE WHEN t.IsParlay = 0 THEN b.liveindicator ELSE t.liveindicator END
        , stake = b.stake 
        , actualrate = b.actualrate  
        , tpositiontaking = b.tpositiontaking 
        , winlostdate = CASE WHEN t.IsParlay = 0 THEN b.winlostdate ELSE t.winlostdate END
        , bettype  = CASE WHEN t.IsParlay = 0 THEN b.bettype ELSE t.bettype END
        , betteam = b.betteam
        , Subbetteam = b.betteam
        , livehomescore  = CASE WHEN t.IsParlay = 0 THEN b.livehomescore ELSE t.livehomescore END
        , liveawayscore  = CASE WHEN t.IsParlay = 0 THEN b.liveawayscore ELSE t.liveawayscore END
        , selection = CASE WHEN t.IsParlay = 1 AND ISNULL(b.oddsspread,0) <> 3 THEN b.hdp2 --Mix/System parlay
						   WHEN t.IsParlay = 1 AND ISNULL(b.oddsspread,0) = 3 THEN b.betid --Hybrid parlay
						   ELSE 0 END
        , statusid = CASE WHEN t.IsParlay = 0 THEN b.statusid ELSE t.statusid END
        , refno = b.refno
    FROM #temp_Ticket t
		CROSS APPLY (
			SELECT liveindicator, transdate, stake, actualrate, tpositiontaking, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, hdp2, statusid, refno, oddsspread, betid
			FROM dbo.bettrans_bk b WITH (NOLOCK) 
			WHERE b.TransId = t.MainTransId
            UNION 
			SELECT liveindicator, transdate, stake, actualrate, tpositiontaking, winlostdate, TransId, bettype, betteam, livehomescore, liveawayscore, hdp2, statusid, refno, oddsspread, betid
			FROM bodb02.dbo.bettrans14 b WITH (NOLOCK) 
			WHERE b.TransId = t.MainTransId
		)b

---Update for case MBU T5 not copy zzzbetrans_bk, T6 delete zzzbettrans => miss data 
UPDATE t
SET Transid_void = vt.TransId
FROM #temp_Ticket t
	INNER JOIN dbo.TicketVoiding_VoidedTransaction_bk vt WITH (NOLOCK) ON t.TransId = vt.TransId
WHERE IsArchived = 1
	AND Transid_void IS NULL 
	AND t.statusID = 102 --VOID

UPDATE t
SET Transid_void = vt.TransId
FROM #temp_Ticket t
	INNER JOIN bodb02.dbo.TicketVoiding_VoidedTransaction vt WITH (NOLOCK) ON t.TransId = vt.TransId
WHERE IsArchived = 1
	AND Transid_void IS NULL 
	AND t.statusID = 102 --VOID

------------------------------------------------------------------------------------
IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE isparlay = 1)
BEGIN
	IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE betteam = '1')
    BEGIN
		UPDATE t
		SET t.stake_tmp = CAST (t.stake/t.selection AS FLOAT)
		FROM #temp_Ticket t
		WHERE isparlay = 1 AND betteam = '1' AND t.statusID = 102
	END
		 
	IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE betteam <> '1')
	BEGIN
		;WITH CTE_Sumstake AS(
		SELECT SUM((bp.stake / SUBSTRING(CAST(bp.Serial AS VARCHAR(20)), 2, 2))) AS Sumstake
				,bp.Refno
				,bp.TransId --Sub ticket
		FROM DBTRANS.bodb02.dbo.BetParlayDetail bp (NOLOCK) 
		WHERE EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket t
										WHERE t.IsParlay = 1 AND t.betteam <> '1' AND bp.refno = t.refno AND bp.transid = t.transid AND t.statusID = 102)
		GROUP BY Refno, TransId
		)
		UPDATE t
		SET t.stake_tmp = cte.Sumstake
		FROM #temp_Ticket t
			INNER JOIN CTE_Sumstake cte ON t.refno = cte.refno AND t.transid = cte.transid
		WHERE IsParlay = 1 AND betteam <> '1' AND t.statusID = 102
		 
		--For main parlay status: Reject, sub parlay: VOID, table : BetParlayDetail (no data).
		IF EXISTS ( SELECT TOP 1 1 FROM #temp_Ticket WHERE isparlay = 1 AND betteam <> '1' AND statusID = 102 AND stake_tmp IS NULL)
		BEGIN
		UPDATE t
			SET t.stake_tmp = CAST (t.stake/t.selection AS FLOAT), IsMissBetParlayDetail = 1
			FROM #temp_Ticket t
			WHERE IsParlay = 1 AND betteam <> '1' AND t.statusID = 102 AND stake_tmp IS NULL
		END
	END
	UPDATE #temp_Ticket
	SET stake = stake_tmp
	WHERE isparlay = 1  AND stake_tmp IS NOT NULL
END
     
	UPDATE t
	SET t.TotalTicket = kq.TotalTicket
	,t.TotalTicket_Parlay = kq.TotalTicket_Parlay
    ,t.Min_Trans = kq.Min_Trans
	,t.Max_Trans = kq.Max_Trans
    ,t.Min_Trans_SubParlay = kq.Min_Trans_SubParlay
	,t.Max_Trans_SubParlay = kq.Max_Trans_SubParlay
	,t.Min_TransDate = kq.Min_TransDate
	,t.Max_TransDate = kq.Max_TransDate
	,t.Liveindicator = CASE WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt > 0 THEN 'Both'
							WHEN kq.Live_cnt > 0 AND kq.NonLive_cnt = 0 THEN 'Liveball'
							WHEN kq.Live_cnt = 0 AND kq.NonLive_cnt > 0 THEN 'Deadball'
						END
	,t.Bet_cnt = kq.Bet_cnt
    ,t.Bet_cnt_Parlay = kq.Bet_cnt_Parlay
	,t.MemberTO_RM = kq.MemberTO_RM
	,t.House_TO_RM = kq.House_TO_RM
	,t.winlostdate = kq.winlostdate
	,t.IsHasSettled = kq.IsHasSettled
    FROM #temp_transid t
	INNER JOIN (
		 SELECT t.RequestId
			 ,b.MatchId
			 ,MIN(b.winlostdate) AS winlostdate
			 ,COUNT(CASE WHEN b.IsParlay = 0 THEN b.TransId ELSE NULL END) AS TotalTicket
			 ,COUNT(CASE WHEN b.IsParlay = 1 THEN b.TransId ELSE NULL END) AS TotalTicket_Parlay
             ,MIN(b.TransId) AS Min_Trans
			 ,MAX(b.TransId) AS Max_Trans
			 ,MIN(CASE WHEN b.IsParlay = 1 THEN b.TransId ELSE NULL END) AS Min_Trans_SubParlay
			 ,MAX(CASE WHEN b.IsParlay = 1 THEN b.TransId ELSE NULL END) AS Max_Trans_SubParlay
             ,MIN(b.transdate) AS Min_TransDate --single/main/sub
			 ,MAX(b.transdate) AS Max_TransDate --single/main/sub
			 ,COUNT(CASE WHEN b.liveindicator = 1 THEN b.liveindicator ELSE NULL END) AS Live_cnt 
			 ,COUNT(CASE WHEN b.liveindicator = 0 THEN b.liveindicator ELSE NULL END) AS NonLive_cnt
			 ,COUNT(CASE WHEN b.statusid = 102 AND b.IsParlay = 0 AND b.Transid_void IS NOT NULL THEN b.Transid_void ELSE NULL END) AS Bet_cnt	
             ,COUNT(CASE WHEN b.statusid = 102 AND b.IsParlay = 1 AND b.Transid_void IS NOT NULL THEN b.Transid_void ELSE NULL END) AS Bet_cnt_Parlay	
			 ,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL THEN cast ((b.stake * b.actualrate) as money) ELSE NULL END) AS MemberTO_RM
			 ,SUM(CASE WHEN b.statusid = 102 AND b.Transid_void IS NOT NULL THEN cast( ((1-tpositiontaking)* b.stake * actualrate) as money) ELSE NULL END) AS House_TO_RM	
			 ,MAX(CASE WHEN b.zzz_status IN ('LOSE','WON','DRAW') THEN 1 ELSE 0 END) AS IsHasSettled
		FROM #temp_transid t
			INNER JOIN #temp_Ticket b ON t.RequestId = b.RequestId
		GROUP BY t.RequestId, b.MatchId
	)kq ON t.RequestId = kq.RequestId 
    
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


/*************************************************************************************************************************************
**************************************************************************************************************************************/
UPDATE	t 
		SET MessageContent = ISNULL(ms.Content_en, ms1.Content_en)
FROM	#temp_transid t
	LEFT JOIN  DBMSG.bodb_Message.dbo.[Msg] ms WITH (NOLOCK) ON t.MessageId = ms.MessageId
	LEFT JOIN  DBMSG.bodb_Message_Archive.dbo.[Msg_Archive] ms1 WITH (NOLOCK) ON t.MessageId = ms1.MessageId																						
WHERE t.MessageId IS NOT NULL 

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
    , ISNULL(DATEDIFF(mi, ms.Max_TransDate, ms.CreatedDate),0)  AS 'Duration(mi)'
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
	, ms.IsMissBetParlayDetail
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