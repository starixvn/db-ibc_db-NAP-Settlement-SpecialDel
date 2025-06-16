/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250527@Helen
	Task: Alpha - Potential Winning Limit/Threshold [Redmine: #226060]
	DB:DBSIC-bodb02
*/
USE bodb02
GO

DECLARE @maxTransid BIGINT, @starTime_Initialize DATETIME
SET @maxTransid = XXX
SET @starTime_Initialize = XXX
--should define primary key for the temporary tables

CREATE TABLE #CustList(custid INT PRIMARY KEY )

CREATE TABLE #Diff_Data (ID INT IDENTITY (1,1) PRIMARY KEY, custid INT, AccumToWin MONEY, AccumWinLoss MONEY, bettrans_AccumToWin MONEY, bettrans_AccumWinloss MONEY
						, diff_ToWin MONEY, diff_WinLoss MONEY)

CREATE TABLE #reset (CUSTID INT, LatestResetDate DATETIME)

CREATE TABLE #tmp_batch (custid INT PRIMARY KEY)
CREATE TABLE #temp_wrongsportoffer (Custid INT)
CREATE TABLE #Result(
	id [int] IDENTITY (1,1) PRIMARY KEY,
	custid INT
)

INSERT INTO #temp_wrongsportoffer (Custid)
SELECT DISTINCT c.CustID
FROM dbo.CustWinLimitBet_History c WITH (NOLOCK) 
WHERE c.ActionType = 0 	AND (c.bettype IN (29,38) OR c.Sporttype >99)

INSERT INTO #Result (custid)
SELECT DISTINCT c.custid
FROM #temp_wrongsportoffer b WITH (NOLOCK) 
	INNER JOIN CUSTDB.dbo.vw_Customer c with (nolock) on b.custid = c.custid
WHERE c.site NOT IN ('Special','Hedging')
	AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK) 
					WHERE h.custid = c.custid AND h.actiontype = 100
					AND  h.RepUpdateTime >= '2025-06-13 00:04:00' AND H.RepUpdateTime <= '2025-06-13 00:10:00'
					)
UNION ALL
SELECT custid
FROM CustWinLimitBet_History h WITH (NOLOCK) 
WHERE  h.actiontype = 100 AND h.RepUpdateTime >= '2025-06-13 00:04:00' AND H.RepUpdateTime <= '2025-06-13 00:15:00' 
GROUP BY custid
HAVING COUNT(1) >= 2

INSERT INTO #CustList (custid)
SELECT DISTINCT b.custid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN #Result c with (nolock) on b.custid = c.custid
	CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK) 
										WHERE m.bettype = b.bettype 
										AND m.SportType <= 99
								) AS chk
WHERE (transid > @maxTransid OR b.SettlementTime > @starTime_Initialize ) AND b.bettype NOT IN (29,38)
	AND b.refno = 100000000000 

INSERT INTO #reset (CUSTID, LatestResetDate)
SELECT b.custid, t.LatestResetDate
FROM #CustList b
	CROSS APPLY (SELECT MAX(c.RepUpdateTime) AS LatestResetDate
				FROM CustWinLimitBet_History c WITH (NOLOCK) 
				WHERE c.CustID = b.CustID AND c.ActionType = 100 -- latest reset
				GROUP BY c.CustID
				) AS t

INSERT INTO #Diff_Data (custid, AccumToWin, AccumWinLoss, bettrans_AccumToWin, bettrans_AccumWinloss, diff_ToWin, diff_WinLoss)
SELECT  lm.CustID, lm.AccumToWin, lm.AccumWinLoss, r.ToWin AS bettrans_AccumToWin, r.WinLoss as bettrans_AccumWinloss
	, r.ToWin - lm.AccumToWin AS diff_ToWin, r.WinLoss - lm.AccumWinLoss AS diff_WinLoss
from #CustList t 
	INNER JOIN CustWinLimitBet lm WITH (NOLOCK) ON t.CustID = lm.custid  
	CROSS APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
						, SUM (CASE WHEN b.statusID NOT IN (0,1,101,102,103,111) AND (t2.LatestResetDate IS NULL OR settlementtime > t2.LatestResetDate) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
				 FROM dbo.bettrans b with (nolock)
					CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK) 
								WHERE m.bettype = b.bettype 
								AND m.SportType <= 99
								) AS chk
					OUTER APPLY (SELECT LatestResetDate
								FROM #reset c 
								WHERE c.CustID = b.CustID 
								) AS t2
				 WHERE b.custid = lm.CustID AND b.bettype NOT IN (29, 38)
						AND b.statusID NOT IN (101,102,103,111)
						AND b.refno = 100000000000 
				 GROUP BY b.custid
				 ) AS r
WHERE (lm.AccumToWin <> r.ToWin OR lm.AccumWinLoss <> r.WinLoss)

------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch

DECLARE @debug_message VARCHAR(500)

IF EXISTS (SELECT TOP (1) 1 FROM #Diff_Data)
BEGIN
	
	SET @MaxRow = (SELECT MAX(ID) FROM #Diff_Data)
	SET @Threshold = 1000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold

	WHILE (@MaxRow IS NOT NULL)
	BEGIN
			PRINT @StartRow
			PRINT @StopRow
			
			-- YOUR CODE TO PROCESS DATA FROM @StartRow & @StopRow
			UPDATE lm
				SET AccumToWin = lm.AccumToWin + c.diff_ToWin
					, AccumWinLoss = lm.AccumWinLoss + c.diff_WinLoss
			FROM CustWinLimitBet lm WITH (ROWLOCK, UPDLOCK) 
				INNER JOIN #Diff_Data c ON c.CustID = lm.custid
			WHERE c.ID BETWEEN @StartRow AND @StopRow

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
			RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
			IF @StopRow = @MaxRow BREAK

			WAITFOR DELAY '00:00:00.100' --optional

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold
			IF @StopRow >= @MaxRow
				SET @StopRow = @MaxRow

	END

END

SELECT * FROM #Diff_Data

DROP TABLE #CustList
DROP TABLE #Diff_Data
DROP TABLE #reset