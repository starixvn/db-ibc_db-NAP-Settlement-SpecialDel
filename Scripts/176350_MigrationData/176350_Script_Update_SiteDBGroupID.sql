-----------STEP 1: ALTER SP ExecRep on DBTRANS ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_09]
(
	@transIds VARCHAR(MAX)
	, @SiteDBGroupID SMALLINT = 1
	, @tablename VARCHAR(200) = ''
)
/*
	Created by: 20220811@Helen
	Task: execRep SP for Settlement [Redmine:#176350]
	DB: DBTXN/bodb02
	
	Revisions:
		- 	20220811@Helen: update sitedbgroupid [Redmine:#176350]

	Param's Explanation:
	
	Samlple execution to parse XML

	DECLARE @transIds VARCHAR(MAX), @xml XML
	
	SET @transIds = (SELECT TOP 10 transid as t
		from bettrans (NOLOCK)
		FOR XML RAW ('r'), ROOT ('root'))

	SET @xml = CAST(@transIds as XML)

	SELECT r.value('@t','BIGINT') AS transid
	FROM @transidXML.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@transidXML = NULL))

*/	
AS
BEGIN
	--declare @transIds VARCHAR(MAX)

	DECLARE @transidXML XML
	DECLARE @tempTrans TABLE (TransID BIGINT PRIMARY KEY)

	SET @transidXML = CONVERT(XML, @Transids)
	
	INSERT INTO @tempTrans (TransID)
	SELECT r.value('@t','BIGINT') AS transid
	FROM @transidXML.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@transidXML = NULL))
	
	IF @tablename = 'bettrans'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
		
	IF @tablename = 'bettransm'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF @tablename = 'bettrans14'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	IF @tablename = 'bettransm14'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	/*
	IF @tablename = 'bettransRnG'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF @tablename = 'Translog'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END
	IF @tablename = 'BettransLC'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF @tablename = 'bettransG'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF @tablename = 'bettransRnG14'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF @tablename = 'Translog14'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END

	IF @tablename = 'BettransLC14'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF @tablename = 'bettransG14'
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	*/
			
END

GO
-----------STEP 2: NEED TO RUN ON DBTRANS ONLY - UPDATE sitedbgroupid for scale out licensee at DBTRANS & ALL SubDB ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)
CREATE TABLE #tmp_bettrans_scaleout (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )
CREATE TABLE #tmp_bettrans14_scaleout (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )
CREATE TABLE #tmp_bettransm_scaleout (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )
CREATE TABLE #tmp_bettransm14_scaleout (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )

CREATE TABLE #tmp_batch (transid BIGINT PRIMARY KEY)
--------------------------------------------------------------
INSERT INTO #tmp_cust_scaleout (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('Athena000','SampleSite')
-------------------DATA PREPARATION --------------------------
-- bettrans
INSERT INTO #tmp_bettrans_scaleout (transid)
SELECT transid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
-- bettrans14
INSERT INTO #tmp_bettrans14_scaleout (transid)
SELECT transid, SiteDBGroupID
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
-- bettransm
INSERT INTO #tmp_bettransm_scaleout (transid)
SELECT transid
FROM bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
-- bettransm14
INSERT INTO #tmp_bettransm14_scaleout (transid)
SELECT transid
FROM bettransm14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

---------------------- param declar to process data -----
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
			PRINT @StartRow
			PRINT @StopRow
		
			TRUNCATE TABLE #tmp_batch

			DELETE R
			OUTPUT DELETED.transid
			INTO #tmp_batch (transid)		
			FROM #tmp_bettrans_scaleout R
			WHERE rid BETWEEN @StartRow AND @StopRow
	
			IF @@ROWCOUNT = 0 
				BREAK

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
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
------ 2. bettrans14 - #tmp_bettrans14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettrans14_scaleout)
BEGIN 
	SET @tablename = 'bettrans14'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettrans14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
			PRINT @StartRow
			PRINT @StopRow
		
			TRUNCATE TABLE #tmp_batch

			DELETE R
			OUTPUT DELETED.transid
			INTO #tmp_batch (transid)		
			FROM #tmp_bettrans14_scaleout R
			WHERE rid BETWEEN @StartRow AND @StopRow
	
			IF @@ROWCOUNT = 0 
				BREAK

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
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
------ 3. bettransm - #tmp_bettransm_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransm_scaleout)
BEGIN
	SET @tablename = 'bettransm'
	SET @StartRow = 1		
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransm_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
			PRINT @StartRow
			PRINT @StopRow
		
			TRUNCATE TABLE #tmp_batch

			DELETE R
			OUTPUT DELETED.transid
			INTO #tmp_batch (transid)		
			FROM #tmp_bettransm_scaleout R
			WHERE rid BETWEEN @StartRow AND @StopRow
	
			IF @@ROWCOUNT = 0 
				BREAK

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
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
------ 3. bettransm14 - #tmp_bettransm14_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettransm14_scaleout)
BEGIN 
	SET @tablename = 'bettransm14'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettransm14_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
			PRINT @StartRow
			PRINT @StopRow
		
			TRUNCATE TABLE #tmp_batch

			DELETE R
			OUTPUT DELETED.transid
			INTO #tmp_batch (transid)		
			FROM #tmp_bettransm14_scaleout R
			WHERE rid BETWEEN @StartRow AND @StopRow
	
			IF @@ROWCOUNT = 0 
				BREAK

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
			RAISERROR (@debug_message, 0, 1) WITH NOWAIT

			SET @transIds = (SELECT transid AS t
							FROM #tmp_batch (NOLOCK)
							FOR XML RAW ('r'), ROOT ('root'))

			EXEC ExecRep_NAP_Admin_09 @transIds = @transIds, @SiteDBGroupID = @siteDBGroupID, @tablename = @tablename

			WAITFOR DELAY '00:00:00.010' --optional
			TRUNCATE TABLE #tmp_batch

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold

			IF @StartRow > @MaxRow BREAK
	END
END
GO

/*
------------ CHECKING DATA AFTER RUN SCRIPT -----------------------
SELECT transid
FROM bettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID IS NULL
-- bettrans14
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID IS NULL
-- bettransm
SELECT transid
FROM bettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID IS NULL
-- bettransm14
SELECT transid, SiteDBGroupID
FROM bettransm14 b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE SiteDBGroupID IS NULL

*/
