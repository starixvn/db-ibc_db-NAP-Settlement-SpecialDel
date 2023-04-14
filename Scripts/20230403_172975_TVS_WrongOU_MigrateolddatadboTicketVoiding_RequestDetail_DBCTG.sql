/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230403@July
	Task: TVS - Wrong OU/ 1H OU - Migrate old data TicketVoiding_RequestDetail - [Redmine:#172975]  
	DB: DBCTG-bodb02
*/

USE bodb02
GO

DECLARE @tmpRequestId TABLE (RequestId INT PRIMARY KEY)
CREATE TABLE #tmpRequestInfo_Ticket ( RequestId INT, TransId BIGINT, MatchId INT, IsMixParlay BIT)
CREATE TABLE #tmpRequestInfo ( RequestId INT, LiveIndicator BIT)

INSERT INTO @tmpRequestId (RequestId)
SELECT RequestId
FROM dbo.TicketVoiding_Request WITH(NOLOCK)
WHERE IssueTypeId IN (6,7)

INSERT INTO #tmpRequestInfo_Ticket (RequestId, TransId, MatchId, IsMixParlay)
SELECT r.RequestId, t.TransId, t.matchId, t.IsMixParlay
FROM @tmpRequestId r
	CROSS APPLY (
				SELECT s.RequestId, s.TransId, s.MatchId, 0 AS IsMixParlay
				FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK)
				WHERE r.RequestId = s.RequestId
				UNION ALL
				SELECT p.RequestId, p.TransId, p.MatchId, 1 AS IsMixParlay
				FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay p WITH(NOLOCK)
				WHERE r.RequestId = p.RequestId
		)t

---Range bettrans/bettransm		
INSERT INTO #tmpRequestInfo (RequestId, LiveIndicator )
SELECT DISTINCT s.RequestId, b.liveindicator
FROM #tmpRequestInfo_Ticket s
	INNER JOIN dbo.bettrans b WITH(NOLOCK) on s.TransId = b.transid AND s.MatchId = b.matchid
WHERE s.IsMixParlay = 0

INSERT INTO #tmpRequestInfo (RequestId, LiveIndicator)
SELECT DISTINCT s.RequestId, b.liveindicator
FROM #tmpRequestInfo_Ticket s
	INNER JOIN dbo.bettransm b WITH(NOLOCK) on s.TransId = b.transid AND s.MatchId = b.matchid
WHERE s.IsMixParlay = 1
AND NOT EXISTS ( SELECT TOP 1 1 FROM #tmpRequestInfo tmp WHERE s.RequestId = tmp.RequestId AND b.liveindicator = tmp.LiveIndicator)

---Range bettrans14/bettransm14
IF EXISTS ( SELECT TOP 1 1 FROM @tmpRequestId r 
					LEFT JOIN #tmpRequestInfo tmp ON r.RequestId = tmp.RequestId
				WHERE tmp.RequestId IS NULL
		 )
BEGIN
	INSERT INTO #tmpRequestInfo (RequestId, LiveIndicator )
	SELECT DISTINCT s.RequestId, b.liveindicator
	FROM #tmpRequestInfo_Ticket s
		INNER JOIN dbo.bettrans14 b WITH(NOLOCK) on s.TransId = b.transid AND s.MatchId = b.matchid
	WHERE s.IsMixParlay = 0
	AND NOT EXISTS ( SELECT TOP 1 1 FROM #tmpRequestInfo tmp WHERE s.RequestId = tmp.RequestId AND b.liveindicator = tmp.LiveIndicator)

	INSERT INTO #tmpRequestInfo (RequestId, LiveIndicator)
	SELECT DISTINCT s.RequestId, b.liveindicator
	FROM #tmpRequestInfo_Ticket s
		INNER JOIN dbo.bettransm14 b WITH(NOLOCK) on s.TransId = b.transid AND s.MatchId = b.matchid
	WHERE s.IsMixParlay = 1
	AND NOT EXISTS ( SELECT TOP 1 1 FROM #tmpRequestInfo tmp WHERE s.RequestId = tmp.RequestId AND b.liveindicator = tmp.LiveIndicator)
END

UPDATE rd WITH (ROWLOCK,UPDLOCK)
SET rd.IssueDetail = rd.IssueDetail + ';LiveGameEarlySingleCount:' +  CAST(rd.SingleCount AS VARCHAR(20)) + ';PoolHouseSingleCount:0;PoolHouseMainParlayCount:' +  CAST(rd.MainParlayCount AS VARCHAR(20))
   ,rd.TransIds = CASE WHEN rd.TransIds LIKE '%IsMainMatch="true"%' THEN SUBSTRING(rd.TransIds,0, LEN(rd.TransIds) - 1) +'LiveIndicator ="' + CAST(tmp.LiveIndicator AS VARCHAR(20)) + '" IsLinkGroup1X2="0" IsLinkGroupAIO="0" PoolHouseCheckedBetTypes="" />'
					   WHEN rd.TransIds LIKE '%IsMainMatch="false"%' THEN SUBSTRING(rd.TransIds,0, LEN(rd.TransIds) - 1) +'LiveIndicator ="' + CAST(tmp.LiveIndicator AS VARCHAR(20)) + '" />'
					   ELSE rd.TransIds END
FROM dbo.TicketVoiding_RequestDetail rd
	INNER JOIN #tmpRequestInfo tmp ON rd.RequestId = tmp.RequestId
WHERE rd.IssueDetail NOT LIKE '%LiveGameEarlySingleCount%' AND rd.TransIds NOT LIKE '%IsLinkGroup1X2%'
AND rd.TransIds IS NOT NULL

DROP TABLE #tmpRequestInfo_Ticket
DROP TABLE #tmpRequestInfo