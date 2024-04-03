/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0" isNested="0"></info>*/

USE bodb_CustomerLog_Archive
GO

DROP TABLE IF EXISTS #tmpMatchID

CREATE TABLE #tmp_MatchID ( ID INT IDENTITY(1,1) PRIMARY KEY, matchid INT)

CREATE TABLE #tmp_Update ( matchid INT)


INSERT INTO #tmp_MatchID ( matchid )
SELECT	us.MatchID
FROM	bodb_CustomerLog.dbo.UserLog_Settle us WITH (NOLOCK)
WHERE	us.ActionID = 81049
	AND us.LogDate BETWEEN '2024-02-20' AND '2024-04-04'
UNION
SELECT	us.MatchID
FROM	dbo.UserLog_Settle us WITH (NOLOCK)
WHERE	us.ActionID = 81049
	AND us.LogDate BETWEEN '2024-02-20' AND '2024-04-04'

WHILE (1=1)
BEGIN
	
	DELETE TOP (5000)
	FROM #tmp_MatchID
	OUTPUT Deleted.Matchid
	INTO #tmp_Update (matchid)

	UPDATE p
	SET IsHold = 1
	FROM SettlementPerformanceLog p WITH (NOLOCK)
		INNER JOIN #tmp_Update m
			ON p.matchid = m.matchid
	WHERE ISNULL(p.IsHold,0) = 0
		AND p.StartTime BETWEEN '2024-02-20' AND '2024-04-04'
END
