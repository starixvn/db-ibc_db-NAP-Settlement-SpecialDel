/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250613@Helen
	Task: Alpha - Potential Winning Limit/Threshold [Redmine: #226060]
	DB:DBSIC-bodb02
*/
USE bodb02
GO

CREATE TABLE #CustList(custid INT PRIMARY KEY )
--CREATE TABLE #Diff_Data (ID INT IDENTITY (1,1) PRIMARY KEY, custid INT, AccumToWin MONEY, AccumWinLoss MONEY, bettrans_AccumToWin MONEY, bettrans_AccumWinloss MONEY
--						, diff_ToWin MONEY, diff_WinLoss MONEY)

INSERT INTO #CustList (custid)
SELECT DISTINCT b.custid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN CUSTDB.dbo.vw_Customer c WITH (NOLOCK) on b.custid = c.custid
	CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK)
										WHERE m.bettype = b.bettype
										AND m.SportType <= 99
								) AS chk
WHERE b.bettype NOT IN (29,38)
	AND c.site IN ('IBCIndo')
	AND b.refno = 100000000000

--INSERT INTO #Diff_Data (custid, AccumToWin, AccumWinLoss, bettrans_AccumToWin, bettrans_AccumWinloss, diff_ToWin, diff_WinLoss)
SELECT  lm.CustID, lm.AccumToWin, lm.AccumWinLoss, r.ToWin AS bettrans_AccumToWin
	--, r.WinLoss as bettrans_AccumWinloss
	, r.ToWin - lm.AccumToWin AS diff_ToWin
into #temp1
from #CustList t
	INNER JOIN CustWinLimitBet lm WITH (NOLOCK) ON t.CustID = lm.custid
	OUTER APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
						--, SUM (CASE WHEN b.statusID NOT IN (0,1,101,102,103,111) AND (t2.LatestResetDate IS NULL OR settlementtime > t2.LatestResetDate) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
				 FROM dbo.bettrans b with (nolock)
					CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK)
								WHERE m.bettype = b.bettype
								AND m.SportType < 99
								) AS chk
					--OUTER APPLY (SELECT LatestResetDate
					--			FROM #reset c
					--			WHERE c.CustID = b.CustID
					--			) AS t2
				 WHERE b.custid = lm.CustID AND b.bettype NOT IN (29, 38)
						AND b.statusID NOT IN (101,102,103,111)
						AND b.refno = 100000000000
				 GROUP BY b.custid
				 ) AS r
WHERE (lm.AccumToWin <> r.ToWin) -- OR lm.AccumWinLoss <> r.WinLoss

WAITFOR DELAY '00:00:04.100' --optional

SELECT  lm.CustID, lm.AccumToWin, lm.AccumWinLoss, r.ToWin AS bettrans_AccumToWin
	--, r.WinLoss as bettrans_AccumWinloss
	, r.ToWin - lm.AccumToWin AS diff_ToWin
from #CustList t
	INNER JOIN CustWinLimitBet lm WITH (NOLOCK) ON t.CustID = lm.custid
	OUTER APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
						--, SUM (CASE WHEN b.statusID NOT IN (0,1,101,102,103,111) AND (t2.LatestResetDate IS NULL OR settlementtime > t2.LatestResetDate) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
				 FROM dbo.bettrans b with (nolock)
					CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK)
								WHERE m.bettype = b.bettype
								AND m.SportType < 99
								) AS chk
					--OUTER APPLY (SELECT LatestResetDate
					--			FROM #reset c
					--			WHERE c.CustID = b.CustID
					--			) AS t2
				 WHERE b.custid = lm.CustID AND b.bettype NOT IN (29, 38)
						AND b.statusID NOT IN (101,102,103,111)
						AND b.refno = 100000000000
				 GROUP BY b.custid
				 ) AS r
WHERE (lm.AccumToWin <> r.ToWin) -- OR lm.AccumWinLoss <> r.WinLoss)
	AND t.custid IN (SELECT custid FROM #temp1)
/*
DROP TABLE #CustList
DROP TABLE #Diff_Data
DROP TABLE #temp1
*/