/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221110@Victoria
    Task: Data Migration - CheckSum between SiteDB and DBTrans - Before Deleting Data
    DB: DBCTG-bodb02

	 Revisions:
		- 20221110@Victoria: CheckSum of bet ticket tables [Redmineid:#180033] 
								bettrans
								bettransRnG
								bettransLC
								bettransG
								translog
								bettransm
								BetParlayDetail
								BetParlayResult
								
*/

CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)

CREATE TABLE #tmp_refno_DBTrans
(
	refno BIGINT PRIMARY KEY
)

CREATE TABLE #tmp_refno_SiteDB
(
	refno BIGINT PRIMARY KEY
)

--------------------------------

INSERT INTO #tmp_cust_scaleout (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('Betway')

--#tmp_refno_DBTrans
INSERT INTO #tmp_refno_DBTrans (refno)
SELECT DISTINCT b.refno
FROM dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

INSERT INTO #tmp_refno_DBTrans (refno)
SELECT DISTINCT b.refno
FROM dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

--#tmp_refno_SiteDB
INSERT INTO #tmp_refno_SiteDB (refno)
SELECT DISTINCT b.refno
FROM DBSIG02.bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

INSERT INTO #tmp_refno_SiteDB (refno)
SELECT DISTINCT b.refno
FROM DBSIG02.bodb02.dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

--------------------------------
------bettrans
CREATE TABLE #tmp_DBTrans_bettrans
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_bettrans
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_bettrans
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm],[statuswinlost], [status], [statusID])) AS TotalCheckSumAgg
FROM	dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

INSERT INTO #tmp_SiteDB_bettrans
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm],[statuswinlost], [status], [statusID])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

------bettransRnG
CREATE TABLE #tmp_DBTrans_bettransRnG
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_bettransRnG
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_bettransRnG
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [status], [statusID], [Gameid3rd], [Tranid3rd])) AS TotalCheckSumAgg
FROM	dbo.bettransRnG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId


INSERT INTO #tmp_SiteDB_bettransRnG
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [status], [statusID], [Gameid3rd], [Tranid3rd])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.bettransRnG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

------bettransLC
CREATE TABLE #tmp_DBTrans_bettransLC
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_bettransLC
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_bettransLC
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId, 
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [status], [statusID], [Gameid3rd], [Tranid3rd])) AS TotalCheckSumAgg
FROM	dbo.bettransLC b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId


INSERT INTO #tmp_SiteDB_bettransLC
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId, 
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm], [status], [statusID], [Gameid3rd], [Tranid3rd])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.bettransLC b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

------bettransG
CREATE TABLE #tmp_DBTrans_bettransG
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_bettransG
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_bettransG
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm],[statuswinlost], [status], [statusID])) AS TotalCheckSumAgg
FROM	dbo.bettransG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

INSERT INTO #tmp_SiteDB_bettransG
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm],[statuswinlost], [status], [statusID])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.bettransG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

------translog
CREATE TABLE #tmp_DBTrans_translog
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_translog
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_translog
(
		TransId,
		TotalCheckSumAgg
)
SELECT	translogid,
		CHECKSUM_AGG(CHECKSUM([status], [statusID], [Gameid3rd], [Tranid3rd])) AS TotalCheckSumAgg
FROM	dbo.translog b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	translogid

INSERT INTO #tmp_SiteDB_translog
(
		TransId,
		TotalCheckSumAgg
)
SELECT	translogid,
		CHECKSUM_AGG(CHECKSUM([status], [statusID], [Gameid3rd], [Tranid3rd])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.translog b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	translogid


------bettransm
CREATE TABLE #tmp_DBTrans_bettransm
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_bettransm
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_bettransm
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm],[statuswinlost], [status], [statusID])) AS TotalCheckSumAgg
FROM	dbo.bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

INSERT INTO #tmp_SiteDB_bettransm
(
		TransId,
		TotalCheckSumAgg
)
SELECT	TransId,
		CHECKSUM_AGG(CHECKSUM([winlost], [awinlost], [mwinlost], [swinlost], [playercomm], [comm], [acomm], [scomm],[statuswinlost], [status], [statusID])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
GROUP BY	TransId

------BetParlayDetail
CREATE TABLE #tmp_DBTrans_BetParlayDetail
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_BetParlayDetail
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_BetParlayDetail
(
		TransId,
		TotalCheckSumAgg
)
SELECT	b.refno,
		CHECKSUM_AGG(CHECKSUM([statuswinlost],[statusid])) AS TotalCheckSumAgg
FROM	dbo.BetParlayDetail b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno
GROUP BY	b.refno

INSERT INTO #tmp_SiteDB_BetParlayDetail
(
		TransId,
		TotalCheckSumAgg
)
SELECT	b.refno,
		CHECKSUM_AGG(CHECKSUM([statuswinlost],[statusid])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.BetParlayDetail b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno
GROUP BY	b.refno

------BetParlayResult
CREATE TABLE #tmp_DBTrans_BetParlayResult
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

CREATE TABLE #tmp_SiteDB_BetParlayResult
(
	TransId BIGINT PRIMARY KEY,
	TotalCheckSumAgg BIGINT
)

INSERT INTO #tmp_DBTrans_BetParlayResult
(
		TransId,
		TotalCheckSumAgg
)
SELECT	b.refno,
		CHECKSUM_AGG(CHECKSUM([statusid],[winlost],[awinlost],[mwinlost],[swinlost])) AS TotalCheckSumAgg
FROM	dbo.BetParlayResult b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno
GROUP BY	b.refno

INSERT INTO #tmp_SiteDB_BetParlayResult
(
		TransId,
		TotalCheckSumAgg
)
SELECT	b.refno,
		CHECKSUM_AGG(CHECKSUM([statusid],[winlost],[awinlost],[mwinlost],[swinlost])) AS TotalCheckSumAgg
FROM	DBSIG02.bodb02.dbo.BetParlayResult b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno
GROUP BY	b.refno

---------------------------------------------
---------------------------------------------
SELECT 'bettrans' AS TableName,*
FROM #tmp_DBTrans_bettrans tmp1 
	INNER JOIN #tmp_SiteDB_bettrans tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
UNION ALL
SELECT 'bettransRnG' AS TableName,*
FROM #tmp_DBTrans_bettransRnG tmp1 
	INNER JOIN #tmp_SiteDB_bettransRnG tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
UNION ALL
SELECT 'bettransLC' AS TableName,*
FROM #tmp_DBTrans_bettransLC tmp1 
	INNER JOIN #tmp_SiteDB_bettransLC tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
UNION ALL
SELECT 'bettransG' AS TableName,*
FROM #tmp_DBTrans_bettransG tmp1 
	INNER JOIN #tmp_SiteDB_bettransG tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
UNION ALL
SELECT 'translog' AS TableName,*
FROM #tmp_DBTrans_translog tmp1 
	INNER JOIN #tmp_SiteDB_translog tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
UNION ALL
SELECT 'bettransm' AS TableName,*
FROM #tmp_DBTrans_bettransm tmp1 
	INNER JOIN #tmp_SiteDB_bettransm tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
UNION ALL
SELECT 'BetParlayDetail' AS TableName,*
FROM #tmp_DBTrans_BetParlayDetail tmp1 
	INNER JOIN #tmp_SiteDB_BetParlayDetail tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg
UNION ALL
SELECT 'BetParlayResult' AS TableName,*
FROM #tmp_DBTrans_BetParlayResult tmp1 
	INNER JOIN #tmp_SiteDB_BetParlayResult tmp2 ON tmp2.TransId = tmp1.TransId
WHERE tmp1.TotalCheckSumAgg <> tmp2.TotalCheckSumAgg

---------------------------------------------
---------------------------------------------
DROP TABLE #tmp_cust_scaleout

DROP TABLE #tmp_refno_DBTrans
DROP TABLE #tmp_DBTrans_bettrans
DROP TABLE #tmp_DBTrans_bettransRnG
DROP TABLE #tmp_DBTrans_bettransLC
DROP TABLE #tmp_DBTrans_bettransG
DROP TABLE #tmp_DBTrans_translog
DROP TABLE #tmp_DBTrans_bettransm
DROP TABLE #tmp_DBTrans_BetParlayDetail
DROP TABLE #tmp_DBTrans_BetParlayResult

DROP TABLE #tmp_refno_SiteDB
DROP TABLE #tmp_SiteDB_bettrans
DROP TABLE #tmp_SiteDB_bettransRnG
DROP TABLE #tmp_SiteDB_bettransLC
DROP TABLE #tmp_SiteDB_bettransG
DROP TABLE #tmp_SiteDB_translog
DROP TABLE #tmp_SiteDB_bettransm
DROP TABLE #tmp_SiteDB_BetParlayDetail
DROP TABLE #tmp_SiteDB_BetParlayResult