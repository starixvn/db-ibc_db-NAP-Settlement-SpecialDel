--https://nexdev.net/issues/180442	
/*db061/bodb_archive*/

DECLARE @from datetime, @to datetime																									
SET @from = '2022-10-01'																									
SET @to = '2022-11-01'																									

CREATE TABLE #tmpResult (
    RequestId		INT
	,sporttype int
	,sportName nVARCHAR(100)
	,IssueTypeName	NVARCHAR(200)
	,SubIssueTypeName NVARCHAR(200)
	,ActionName		NVARCHAR(200)
	,UserId			INT
	,CreatedDate	DATETIME
	,MistakenBy		NVARCHAR(200)
	,DecidedBy		NVARCHAR(200)
	,CheckedBy		INT
	,MatchId		INT
	,HomeId			INT
	,AwayId			INT
	,LeagueId		INT
	,LastVoidedBy	NVARCHAR(200)
	,FromWinlostDate DATE
	,ToWinlostDate	DATE
	,TotalUserName	INT
	,IssueTypeId	INT
	,SubIssueTypeId	INT
	,ActionId		INT
	,TotalSingle	INT 
	,Home			NVARCHAR(200)
	,Away			NVARCHAR(200)
	,League			NVARCHAR(200)
	,SettlementStatus NVARCHAR(200)
	,CreatedBy      NVARCHAR(200)
	,CheckedByName   NVARCHAR(200)
)
CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

--Range Archive
INSERT INTO #tmpResult(RequestId, Sporttype, IssueTypeId , SubIssueTypeId, MatchId, HomeId, AwayId, LeagueId , ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, FromWinlostDate, ToWinlostDate, TotalUserName, TotalSingle)
SELECT	distinct r.RequestId
		,r.Sporttype
		,r.IssueTypeId
		,rd.SubIssueTypeId
		,CASE WHEN r.IssueTypeId IN (13) THEN NULL ELSE rd.MatchId END
		,CASE WHEN r.IssueTypeId IN (13) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.HomeId END
		,CASE WHEN r.IssueTypeId IN (13) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.AwayId END
		,CASE WHEN r.IssueTypeId IN (13) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.LeagueId END
		,r.ActionId
		,r.CreatedDate
		,r.UserId
		,r.MistakenBy
		,r.DecidedBy
		,r.CheckedBy
		,rd.FromWinlostDate
		,rd.ToWinlostDate
		,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
		,LEN(ISNULL(ts.TransIds,'')) - LEN(REPLACE(ISNULL(ts.TransIds,''), ',', '')) AS TotalSingle
FROM dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK) ON r.RequestId = rd.RequestId
	OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
					FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)
					WHERE s.RequestId = r.RequestId  
					FOR XML PATH('')
				)ts	 (TransIds)
WHERE	r.IssueTypeId IN (11,13) AND r.IsTest = 0
AND CreatedDate >= @from AND CreatedDate < @to


--Range Active
INSERT INTO #tmpResult(RequestId, Sporttype, IssueTypeId , SubIssueTypeId, MatchId, HomeId, AwayId, LeagueId , ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, FromWinlostDate, ToWinlostDate, TotalUserName, TotalSingle)
SELECT	distinct r.RequestId
		,r.Sporttype
		,r.IssueTypeId
		,rd.SubIssueTypeId
		,CASE WHEN r.IssueTypeId IN (13) THEN NULL ELSE rd.MatchId END
		,CASE WHEN r.IssueTypeId IN (13) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.HomeId END
		,CASE WHEN r.IssueTypeId IN (13) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.AwayId END
		,CASE WHEN r.IssueTypeId IN (13) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.LeagueId END
		,r.ActionId
		,r.CreatedDate
		,r.UserId
		,r.MistakenBy
		,r.DecidedBy
		,r.CheckedBy
		,CONVERT (DATE, rd.FromWinlostDate) 
		,CONVERT (DATE, rd.toWinlostDate) 
		,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
		,LEN(ISNULL(ts.TransIds,'')) - LEN(REPLACE(ISNULL(ts.TransIds,''), ',', '')) AS TotalSingle
FROM bodb02.dbo.TicketVoiding_Request r WITH(NOLOCK)
	INNER JOIN bodb02.dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON r.RequestId = rd.RequestId
	OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
					FROM bodb02.dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
					WHERE s.RequestId = r.RequestId
					FOR XML PATH('')
				)ts	 (TransIds)
WHERE	r.IssueTypeId IN (11,13) AND r.IsTest = 0
AND CreatedDate >= @from AND CreatedDate < @to

UPDATE r
SET r.IssueTypeName = CASE WHEN r.IssueTypeId = 13 THEN 'Abnormal Account' ELSE i.IssueTypeName END
	, r.SubIssueTypeName = s.SubIssueTypeName
	,r.ActionName = CASE WHEN r.ActionId = 6 THEN 'Auto Void All (5m before KO)'
						WHEN r.ActionId = 7 THEN 'Auto Void All (10m before KO)'
						WHEN r.ActionId = 8 THEN 'Auto Void All (Instant w/o Policy)'
						ELSE a.ActionName END
	,CreatedBy = c.username
	,CheckedByName = ch.username
FROM #tmpResult r
LEFT JOIN bodb02.dbo.TicketVoiding_IssueType i WITH(NOLOCK) ON r.IssueTypeId = i.IssueTypeId
LEFT JOIN bodb02.dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON R.SubIssueTypeId = s.SubIssueTypeId
LEFT JOIN bodb02.dbo.TicketVoiding_Action a WITH(NOLOCK) ON r.ActionId = a.ActionId
LEFT JOIN bodb02.dbo.custinfo c WITH(NOLOCK) ON r.UserId = c.CustId
LEFT JOIN bodb02.dbo.custinfo ch WITH(NOLOCK) ON r.CheckedBy = ch.CustId

UPDATE r
SET r.Home = m.home
	,r.Away = m.away
	,r.League = l.leaguename
	,r.SettlementStatus = mr.SettlementStatus
	,r.sportName = m.SportName
FROM #tmpResult r
CROSS APPLY (																								
		SELECT	matchid, leagueid, h.teamname as home, a.teamname as away, m.finalhomescore	, m.finalawayscore, m.hthomescore, m.htawayscore, s.SportName																
		FROM	dbo.match_bk m WITH (NOLOCK)																						
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
			left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid																						
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		WHERE	matchid = r.matchid																						
																									
		UNION ALL																							
		SELECT  matchid, leagueid	, h.teamname as home, a.teamname as away, m.finalhomescore	, m.finalawayscore, m.hthomescore, m.htawayscore, s.SportName																						
		FROM	bodb02.dbo.match14 m WITH (NOLOCK)																						
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
			left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid																						
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		WHERE	matchid = r.matchid																						
																									
		UNION ALL																							
		SELECT  matchid, leagueid , h.teamname as home, a.teamname as away	, m.finalhomescore	, m.finalawayscore, m.hthomescore, m.htawayscore, s.SportName																						
		FROM	bodb02.dbo.match m WITH (NOLOCK)																						
			left join bodb02.dbo.team h with (nolock) on h.teamid = m.homeid																						
			left join bodb02.dbo.team a with (nolock) on a.teamid = m.awayid																						
			left join bodb02.dbo.Sports s with (nolock) on s.SportType = m.sporttype																						
		WHERE	matchid = r.matchid	
	) m																								
	INNER JOIN bodb02.dbo.League l WITH (NOLOCK)																								
		ON m.leagueid = l.leagueid	
	OUTER APPLY(
					SELECT CASE WHEN mr.calculate = 1 THEN 'FT: ' + CAST(m.finalhomescore AS VARCHAR(10)) + '-' + CAST(finalawayscore AS VARCHAR(10))
								WHEN mr.IsHTCal = 1 THEN 'HT: ' + CAST(m.hthomescore AS VARCHAR(10)) + '-' + CAST(m.htawayscore AS VARCHAR(10))
							ELSE 'HT: _-_' END AS SettlementStatus
					FROM dbo.match_remark mr WITH (NOLOCK) 
					WHERE mr.matchid = r.MatchId
			)mr
WHERE l.isTest = 0	AND r.IssueTypeId IN (11)
 
--Range archive
UPDATE	t 
	SET LastVoidedBy = v.username
FROM	#tmpResult t
	CROSS APPLY (
		SELECT	TOP (1) vh.UserId AS LastVoidedBy
		FROM	dbo.TicketVoiding_VoidingHistory_bk vh WITH(NOLOCK)
		WHERE	vh.RequestId = t.RequestId AND vh.StatusId IN (2,3)
	) vh
	LEFT JOIN bodb02.dbo.custinfo v WITH(NOLOCK)
		ON vh.LastVoidedBy = v.CustId

--Range active
UPDATE	t 
	SET LastVoidedBy = v.username
FROM	#tmpResult t
	CROSS APPLY (
		SELECT	TOP (1) vh.UserId AS LastVoidedBy
		FROM	bodb02.dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		WHERE	vh.RequestId = t.RequestId AND vh.StatusId IN (2,3)
	) vh
	LEFT JOIN bodb02.dbo.custinfo v WITH(NOLOCK)
		ON vh.LastVoidedBy = v.CustId
WHERE EXISTS (SELECT TOP 1 1 FROM #tmpResult r WHERE t.RequestId = r.RequestId AND t.LastVoidedBy IS NULL)

--Return Data
	SELECT  DISTINCT 
			 t.RequestId
			,t.sportName
			,t.IssueTypeName
			,t.SubIssueTypeName
			,t.MatchId
			,t.SettlementStatus
			,t.TotalSingle
			,t.TotalUserName --no.of accounts
			,CONVERT(VARCHAR(10),t.FromWinlostDate,111) + ' - ' + CONVERT(VARCHAR(10),t.ToWinlostDate,111) AS VoidTime
			,t.Home + ' - vs - ' +  t.Away AS Event
			,t.League
			,t.ActionName
			,t.CreatedBy
			,t.CreatedDate
			,t.MistakenBy
			,t.DecidedBy 
			,t.LastVoidedBy  as LastPerformedBy
			,t.CheckedByName AS CheckedBy
	FROM	#tmpResult t

DROP TABLE #tmpResult