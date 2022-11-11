/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221110@Victoria
    Task: Data Migration - Check Ticket Count of SiteDB and DBTrans - After Deleting Data
    DB: DBCTG-bodb02

	 Revisions:
		- 20221110@Victoria: Check TicketCount of bet ticket tables [Redmineid:#180033] 
								bettrans
								bettrans14
								bettransRnG
								bettransRnG14
								bettransLC
								bettransLC14
								bettransG
								bettransG14
								translog
								translog14
								bettransm
								bettransm14
								BetParlayDetail
								BetParlayResult
							Check 'Void' tickets but they are not being exists in the following tables: 
								zzzbettrans
								zzzbettransm
								
*/

CREATE TABLE #tmp_betticketcheckcount_DBTrans
(
	TableName VARCHAR(50),
	TicketCount INT
)

CREATE TABLE #tmp_betticketcheckcount_SiteDB
(
	TableName VARCHAR(50),
	TicketCount INT
)

CREATE TABLE #tmp_refno_DBTrans
(
	refno BIGINT PRIMARY KEY
)

CREATE TABLE #tmp_refno_SiteDB
(
	refno BIGINT PRIMARY KEY
)

CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)

--------------------------------------------------
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
FROM DBSIG01.SiteDB01tmp.dbo.bettrans_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

INSERT INTO #tmp_refno_SiteDB (refno)
SELECT DISTINCT b.refno
FROM DBSIG01.SiteDB01tmp.dbo.bettrans14_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE bettype = 29 AND matchid = 29

---Count ticket on DBTrans
INSERT INTO #tmp_betticketcheckcount_DBTrans
(
		TableName,
		TicketCount
)
SELECT	'bettrans' AS TableName,
		COUNT(1) AS TicketCount
FROM	dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettrans14' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransRnG' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransRnG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransRnG14' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransRnG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransLC' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransLC b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransLC14' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransLC14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransG' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransG14' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'translog' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.translog b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'translog14' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.translog14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransm' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransm b WITH (NOLOCK) 
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransm14' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.bettransm14 b WITH (NOLOCK) 
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'BetParlayDetail' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.BetParlayDetail b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno
UNION ALL
SELECT	'BetParlayResult' AS TableName,
		COUNT(1) AS TicketCount
FROM dbo.BetParlayResult b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno

---Count ticket on SiteDB
INSERT INTO #tmp_betticketcheckcount_SiteDB
(
		TableName,
		TicketCount
)
SELECT	'bettrans' AS TableName,
		COUNT(1) AS TicketCount
FROM	DBSIG01.SiteDB01tmp.dbo.bettrans_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettrans14' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettrans14_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransRnG' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransRnG_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransRnG14' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransRnG14_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransLC' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransLC_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransLC14' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransLC14_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransG' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransG_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransG14' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransG14_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'translog' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.translog_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'translog14' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.translog14_delete b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransm' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransm_delete b WITH (NOLOCK) 
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'bettransm14' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.bettransm14_delete b WITH (NOLOCK) 
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = b.custid
UNION ALL
SELECT	'BetParlayDetail' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.BetParlayDetail_delete b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno
UNION ALL
SELECT	'BetParlayResult' AS TableName,
		COUNT(1) AS TicketCount
FROM DBSIG01.SiteDB01tmp.dbo.BetParlayResult_delete b WITH (NOLOCK)
	INNER JOIN #tmp_refno_DBTrans tmp ON tmp.refno = b.refno

-----------------------------------
/**********Check 'Void' tickets but they are not being exists in zzzbettrans and zzzbettransm*********/

CREATE TABLE #tmp_zzzbettrans_DBTrans
(
	transid BIGINT PRIMARY KEY
)

CREATE TABLE #tmp_zzzbettransm_DBTrans
(
	transid BIGINT PRIMARY KEY
)

INSERT INTO #tmp_zzzbettrans_DBTrans (transid)
SELECT DISTINCT b.transid
FROM dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID = 102

INSERT INTO #tmp_zzzbettrans_DBTrans (transid)
SELECT DISTINCT b.transid
FROM dbo.bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID = 102

INSERT INTO #tmp_zzzbettransm_DBTrans (transid)
SELECT DISTINCT b.transid
FROM dbo.bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID = 102

INSERT INTO #tmp_zzzbettransm_DBTrans (transid)
SELECT DISTINCT b.transid
FROM dbo.bettransm14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout tmp WITH (NOLOCK) ON tmp.custid = b.custid
WHERE b.statusID = 102

-----------------------------------
SELECT *
FROM #tmp_betticketcheckcount_DBTrans tmp1 
	INNER JOIN #tmp_betticketcheckcount_SiteDB tmp2 ON tmp2.TableName = tmp1.TableName
WHERE tmp1.TicketCount <> tmp2.TicketCount

SELECT tmp.*
FROM #tmp_zzzbettrans_DBTrans tmp 
	LEFT JOIN zzzbettrans b WITH (NOLOCK) ON b.transid = tmp.transid
WHERE b.transid IS NULL
UNION ALL
SELECT tmp.*
FROM #tmp_zzzbettransm_DBTrans tmp 
	LEFT JOIN zzzbettransm b WITH (NOLOCK) ON b.transid = tmp.transid
WHERE b.transid IS NULL

-----------------------------------
DROP TABLE #tmp_cust_scaleout

DROP TABLE #tmp_refno_DBTrans
DROP TABLE #tmp_betticketcheckcount_DBTrans

DROP TABLE #tmp_refno_SiteDB
DROP TABLE #tmp_betticketcheckcount_SiteDB

DROP TABLE #tmp_zzzbettrans_DBTrans
DROP TABLE #tmp_zzzbettransm_DBTrans
