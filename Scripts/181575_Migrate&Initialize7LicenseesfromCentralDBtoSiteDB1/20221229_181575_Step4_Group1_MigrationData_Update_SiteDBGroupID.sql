/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created by: 20221229@July
    Task: Data Migration
    DB: DBCTG-bodb02

	Revisions:
		- 20221229@July: UPDATE sitedbgroupid for scale out licensee at DBTRANS & ALL SubDB [Redmineid:#181575] 
*/

-----------STEP 2: NEED TO RUN ON DBTRANS ONLY - UPDATE sitedbgroupid for scale out licensee at DBTRANS & ALL SubDB ------------------------------------------
USE bodb02
GO

CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)
CREATE TABLE #tmp_bettrans_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
CREATE TABLE #tmp_batch (transid BIGINT PRIMARY KEY)
--------------------------------------------------------------
INSERT INTO #tmp_cust_scaleout (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('ZFRT152','ZFRT166SW','4300','aws03','MTechCV','Fabbet','GSCFTWCV','Betway')

-------------------DATA PREPARATION --------------------------
-- bettrans
INSERT INTO #tmp_bettrans_scaleout (transid)
SELECT transid
FROM dbo.bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
---------------------- param declare to process data -----
DECLARE @StartRow INT = 1
	, @StopRow INT 
	, @MaxRow INT 
	, @Threshold INT = 2000 -- the number of each batch
	, @tablename VARCHAR (200)
	, @transIds VARCHAR (MAX) = ''
	, @siteDBGroupID SMALLINT = 1

DECLARE @debug_message VARCHAR(500)

------ 1. bettrans - #tmp_bettrans_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettrans_scaleout)
BEGIN
	SET @tablename = 'bettrans'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettrans_scaleout)
	-- SET for first batch
	SET @StopRow = @Threshold
	WHILE (1 = 1)
	BEGIN

		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_bettrans_scaleout R
		WHERE rid BETWEEN @StartRow AND @StopRow
	
		IF @@ROWCOUNT = 0 
			BREAK

		SET @debug_message = @tablename + ' StartRow: ' + CAST(@StartRow AS VARCHAR)  + ' StopRow: ' + CAST(@StopRow AS VARCHAR(50)) + ' ' + CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		SET @transIds = (SELECT transid AS t
						FROM #tmp_batch 
						FOR XML RAW ('r'), ROOT ('root'))

		EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

		WAITFOR DELAY '00:00:00.010' --optional
		TRUNCATE TABLE #tmp_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StartRow > @MaxRow BREAK

	END
END

/*
------------ CHECKING DATA AFTER RUN SCRIPT -----------------------
--bettrans
SELECT transid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettrans14
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransm
SELECT transid
FROM bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransm14
SELECT transid
FROM bettransm14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
	
-- bettransLC
SELECT transid
FROM bettransLC b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransLC14
SELECT transid
FROM bettransLC14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransRnG
SELECT transid
FROM bettransRnG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransRnG14
SELECT transid
FROM bettransRnG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransG
SELECT transid
FROM bettransG b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- bettransG14
SELECT transid
FROM bettransG14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- translog
SELECT translogid
FROM translog b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
-- translog14
SELECT translogid
FROM translog14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--zzzbettrans
SELECT transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--zzzbettransm
SELECT b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_Single
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_Single
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN bettrans14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

--TicketVoiding_RequestDetailTicket_SubParlay
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN bettransm14 s ON s.transid = b.transid AND s.matchid = b.MatchId
	INNER JOIN #tmp_cust_scaleout tmp ON tmp.custid = s.custid
WHERE b.SiteDBGroupID = 0 OR b.SiteDBGroupID IS NULL

*/


