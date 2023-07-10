/*DBARC-bodb_archive*/
DECLARE @RequestIds VARCHAR(MAX) = '82558'

DECLARE @tmp_Request AS TABLE (RequestId INT)
INSERT INTO @tmp_Request (RequestId)
SELECT DISTINCT value
FROM string_split(@RequestIds, ',')

CREATE TABLE #Result (
	RequestId INT
	, MatchId INT
	, TotalTicket INT
	, Min_Trans BIGINT
	, Max_Trans BIGINT
	, Min_TransDate DATETIME
	, Max_TransDate DATETIME
	, Live_cnt INT
	, NonLive_cnt INT
)
INSERT INTO #Result (RequestId, MatchId, TotalTicket, Min_Trans, Max_Trans, Min_TransDate, Max_TransDate, Live_cnt, NonLive_cnt)
SELECT t.RequestId
	,s.MatchId
	,COUNT(s.TransId) AS TotalTicket
	,MIN(s.TransId) AS Min_Trans
	,MAX(s.TransId) AS Max_Trans
	,MIN(b.transdate) AS Min_TransDate
	,MAX(b.transdate) AS Max_TransDate
	,COUNT(CASE WHEN b.liveindicator = 1 THEN b.liveindicator ELSE NULL END) AS Live_cnt 
	,COUNT(CASE WHEN b.liveindicator = 0 THEN b.liveindicator ELSE NULL END) AS NonLive_cnt 
FROM @tmp_Request t
	INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK) ON t.RequestId = s.RequestId
	CROSS APPLY (
		SELECT liveindicator, transdate
		FROM dbo.bettrans_bk b WITH (NOLOCK) 
		WHERE b.TransId = s.TransId
	)b
GROUP BY t.RequestId, s.MatchId

SELECT RequestId, MatchId, TotalTicket
	,CASE WHEN Live_cnt > 0 AND NonLive_cnt > 0 THEN 'Both'
		WHEN Live_cnt > 0 AND NonLive_cnt = 0 THEN 'Liveball'
		WHEN Live_cnt = 0 AND NonLive_cnt > 0 THEN 'Deadball'
	END AS Liveindicator
	, Min_Trans, Max_Trans, Min_TransDate, Max_TransDate
FROM #Result

DROP TABLE #Result