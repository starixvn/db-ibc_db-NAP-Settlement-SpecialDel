/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220928@July
	Task: Migrate data column winlost bettransm14 - [Redmine:#175412]  
	DB: DBCTG-bodb02
*/

USE bodb02
GO

CREATE TABLE #tmptransid (transid BIGINT, winlost MONEY)
INSERT INTO #tmptransid (transid, winlost)
SELECT 30868428176752642, 1
UNION ALL SELECT 30868479716360193, 1
UNION ALL SELECT 30871610747518977, 5
UNION ALL SELECT 30930829756596226, 5
UNION ALL SELECT 30930872706269186, 5
UNION ALL SELECT 30930894181105670, 5
UNION ALL SELECT 31226250492116997, 1
UNION ALL SELECT 31226250492117000, 1
SELECT * FROM #tmptransid

UPDATE b 
SET b.winlost = t.winlost
FROM dbo.bettransm14 b WITH(ROWLOCK, UPDLOCK)
	INNER JOIN #tmptransid t ON b.transid = t.transid

DROP TABLE #tmptransid


