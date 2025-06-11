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

CREATE TABLE #Diff_Data (custid INT, AccumToWin MONEY, AccumWinLoss MONEY, bettrans_AccumToWin MONEY, bettrans_AccumWinloss MONEY
						, diff_ToWin MONEY, diff_WinLoss MONEY)

CREATE TABLE #reset (CUSTID INT, LatestResetDate DATETIME)

INSERT INTO #CustList (custid)
SELECT DISTINCT b.custid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN CUSTDB.dbo.vw_Customer c with (nolock) on b.custid = c.custid
	CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK) 
										WHERE m.bettype = b.bettype 
										AND m.SportType < 99
								) AS chk
WHERE (transid > @maxTransid OR b.SettlementTime > @starTime_Initialize ) AND b.currency = 20 AND b.bettype NOT IN (29,38)
	AND c.site NOT IN ('Special','Hedging')

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
from #CustList t with (nolock)
	INNER JOIN CustWinLimitBet lm WITH (NOLOCK) ON t.CustID = lm.custid  
	CROSS APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
						, SUM (CASE WHEN b.statusID NOT IN (0,1,101,102,103,111) AND (t2.LatestResetDate IS NULL OR settlementtime > t2.LatestResetDate) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
				 FROM dbo.bettrans b with (nolock)
					CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK) 
								WHERE m.bettype = b.bettype 
								AND m.SportType < 99
								) AS chk
					OUTER APPLY (SELECT LatestResetDate
								FROM #reset c 
								WHERE c.CustID = b.CustID 
								) AS t2
				 WHERE b.custid = lm.CustID AND b.bettype NOT IN (29, 38)
						AND b.statusID NOT IN (101,102,103,111)
				 GROUP BY b.custid
				 ) AS r
WHERE (lm.AccumToWin <> r.ToWin OR lm.AccumWinLoss <> r.WinLoss)

IF EXISTS (SELECT TOP (1) 1 FROM #Diff_Data)
BEGIN
	UPDATE lm
		SET AccumToWin = lm.AccumToWin + c.diff_ToWin
			, AccumWinLoss = lm.AccumWinLoss + c.diff_WinLoss
		OUTPUT deleted.CustID,deleted.Sporttype, deleted.Bettype,inserted.AccumToWin - deleted.AccumToWin, inserted.AccumWinLoss - deleted.AccumWinLoss, 100 AS ActionType, dbo.f_GetDateTime2()
		INTO CustWinLimitBet_History (custid, Sporttype, Bettype, AdjToWin, AdjWinLoss, ActionType,RepUpdateTime)
	
	FROM CustWinLimitBet lm WITH (ROWLOCK, UPDLOCK) 
		INNER JOIN #Diff_Data c ON c.CustID = lm.custid

END
SELECT * FROM #Diff_Data

DROP TABLE #CustList
DROP TABLE #Diff_Data
DROP TABLE #reset