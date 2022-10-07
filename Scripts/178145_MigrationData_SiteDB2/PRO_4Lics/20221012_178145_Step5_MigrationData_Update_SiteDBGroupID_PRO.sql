-----------STEP 1: ALTER SP ExecRep on DBTRANS ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_09]
(
	@transIds VARCHAR(MAX)
	, @SiteDBGroupID SMALLINT = 2
	, @tablename VARCHAR(200) = ''
)
/*
	Created by: 20220926@Victoria
	Task: execRep SP for Settlement [Redmine:#178145]
	DB: DBCTG-bodb02
	
	Revisions:
		- 	20220926@Victoria: update sitedbgroupid [Redmine:#178145]

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
	SET NOCOUNT ON

	DECLARE @transidXML XML
	DECLARE @tempTrans TABLE (TransID BIGINT PRIMARY KEY)

	SET @transidXML = CONVERT(XML, @Transids)
	
	INSERT INTO @tempTrans (TransID)
	SELECT r.value('@t','BIGINT') AS transid
	FROM @transidXML.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@transidXML = NULL))
	
	IF (@tablename = 'bettrans' AND OBJECT_ID(N'dbo.bettrans') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettrans14' AND OBJECT_ID(N'dbo.bettrans14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettrans14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
		
	IF (@tablename = 'bettransm' AND OBJECT_ID(N'dbo.bettransm') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettransm14' AND OBJECT_ID(N'dbo.bettransm14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransm14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransRnG' AND OBJECT_ID(N'dbo.bettransRnG') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettransRnG14' AND OBJECT_ID(N'dbo.bettransRnG14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransRnG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'Translog' AND OBJECT_ID(N'dbo.Translog') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END

	IF (@tablename = 'Translog14' AND OBJECT_ID(N'dbo.Translog14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.Translog14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.translogid = t.TransId
	END

	IF (@tablename = 'BettransLC' AND OBJECT_ID(N'dbo.BettransLC') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'BettransLC14' AND OBJECT_ID(N'dbo.BettransLC14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.BettransLC14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
	
	IF (@tablename = 'bettransG' AND OBJECT_ID(N'dbo.bettransG') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'bettransG14' AND OBJECT_ID(N'dbo.bettransG14') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.bettransG14 b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'zzzbettrans' AND OBJECT_ID(N'dbo.zzzbettrans') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'zzzbettransm' AND OBJECT_ID(N'dbo.zzzbettransm') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'TicketVoiding_RequestDetailTicket_Single' AND OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_Single') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.TicketVoiding_RequestDetailTicket_Single b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF (@tablename = 'TicketVoiding_RequestDetailTicket_SubParlay' AND OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_SubParlay') is not null)
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.TicketVoiding_RequestDetailTicket_SubParlay b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END
			
END

GO
-----------STEP 2: NEED TO RUN ON DBTRANS ONLY - UPDATE sitedbgroupid for scale out licensee at DBTRANS & ALL SubDB ------------------------------------------
/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/

CREATE TABLE #tmp_cust_scaleout (custid INT PRIMARY KEY)

CREATE TABLE #tmp_bettrans (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)

CREATE TABLE #tmp_table_list (rid INT IDENTITY (1,1) PRIMARY KEY, tablename VARCHAR(200))

CREATE TABLE #tmp_batch (transid BIGINT PRIMARY KEY)
--------------------------------------------------------------
INSERT INTO #tmp_table_list (tablename)
VALUES	  ('bettrans')
		, ( 'bettrans14')
		, ('bettransm')
		, ('bettransm14')
		, ('bettransRnG')
		, ('bettransRnG14')
		, ('Translog')
		, ('Translog14')
		, ('BettransLC')
		, ('BettransLC14')
		, ('bettransG')
		, ('bettransG14')
		, ('zzzbettrans')
		, ('zzzbettransm')
		, ('TicketVoiding_RequestDetailTicket_Single')
		, ('TicketVoiding_RequestDetailTicket_SubParlay')

-----------------------------------------------------------
INSERT INTO #tmp_cust_scaleout (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('OneSports', '9club', 'X2Dynamic', 'Macaubet')
-------------------------------------------------------------

DECLARE @StartRow INT = 1
	, @StopRow INT 
	, @MaxRow INT 
	, @Threshold INT = 2000 -- the number of each batch
	, @tablename VARCHAR (200)
	, @transIds VARCHAR (MAX) = ''
	, @siteDBGroupID SMALLINT = 2
	, @rid_table INT = 1
	, @max_rid_table INT
	, @query NVARCHAR (max)

DECLARE @debug_message VARCHAR(500)

SELECT @max_rid_table = MAX(rid) FROM #tmp_table_list

WHILE (@rid_table <= @max_rid_table)
BEGIN
	SELECT @tablename = tablename FROM #tmp_table_list WHERE rid = @rid_table

	SET  @query = CASE	@tablename	WHEN  'bettrans' THEN	'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettrans b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettrans14' THEN	'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettrans14 b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransm' THEN	'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransm b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransm14' THEN 'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransm14 b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransLC' THEN 'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransLC b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransLC14' THEN 'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransLC14 b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransRnG' THEN 'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransRnG b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransRnG14' THEN 'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransRnG14 b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransG' THEN   'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransG b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'bettransG14' THEN   'INSERT INTO #tmp_bettrans (transid) 
																SELECT b.transid 
																FROM bettransG14 b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'zzzbettrans' THEN   'INSERT INTO #tmp_bettrans (transid) 
																SELECT DISTINCT b.transid 
																FROM zzzbettrans b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'zzzbettransm' THEN   'INSERT INTO #tmp_bettrans (transid) 
																SELECT DISTINCT b.transid 
																FROM zzzbettransm b WITH (NOLOCK)
																	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'TicketVoiding_RequestDetailTicket_Single' THEN  'INSERT INTO #tmp_bettrans (transid) 
																							SELECT DISTINCT tsingle.transid 
																							FROM TicketVoiding_RequestDetailTicket_Single tsingle WITH (NOLOCK)
																								INNER JOIN bettrans b WITH (NOLOCK) ON b.transid = tsingle.transid
																								INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
																							INSERT INTO #tmp_bettrans (transid) 
																							SELECT DISTINCT tsingle.transid 
																							FROM TicketVoiding_RequestDetailTicket_Single tsingle WITH (NOLOCK)
																								INNER JOIN bettrans14 b WITH (NOLOCK) ON b.transid = tsingle.transid
																								INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
									WHEN  'TicketVoiding_RequestDetailTicket_SubParlay' THEN  'INSERT INTO #tmp_bettrans (transid) 
																							SELECT DISTINCT tparlay.transid 
																							FROM TicketVoiding_RequestDetailTicket_SubParlay tparlay WITH (NOLOCK)
																								INNER JOIN bettrans b WITH (NOLOCK) ON b.transid = tparlay.transid
																								INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
																							INSERT INTO #tmp_bettrans (transid) 
																							SELECT DISTINCT tparlay.transid 
																							FROM TicketVoiding_RequestDetailTicket_SubParlay tparlay WITH (NOLOCK)
																								INNER JOIN bettrans14 b WITH (NOLOCK) ON b.transid = tparlay.transid
																								INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid'
					END

	EXEC sys.sp_executesql @query

	IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettrans) 
	BEGIN
		SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettrans)
			
		SET @StartRow = 1		
		-- SET for first batch
		SET @StopRow = @Threshold 
		WHILE (1 = 1)
		BEGIN
			TRUNCATE TABLE #tmp_batch

			DELETE R
			OUTPUT DELETED.transid
			INTO #tmp_batch (transid)		
			FROM #tmp_bettrans R
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

	TRUNCATE TABLE #tmp_bettrans
	SET @rid_table = @rid_table + 1

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
SELECT tsingle.transid 
FROM TicketVoiding_RequestDetailTicket_Single tsingle WITH (NOLOCK)
	INNER JOIN bettrans b WITH (NOLOCK) ON b.transid = tsingle.transid
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

SELECT tsingle.transid 
FROM TicketVoiding_RequestDetailTicket_Single tsingle WITH (NOLOCK)
	INNER JOIN bettrans14 b WITH (NOLOCK) ON b.transid = tsingle.transid
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

--TicketVoiding_RequestDetailTicket_SubParlay
SELECT tparlay.transid 
FROM TicketVoiding_RequestDetailTicket_SubParlay tparlay WITH (NOLOCK)
	INNER JOIN bettrans b WITH (NOLOCK) ON b.transid = tparlay.transid
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

SELECT tparlay.transid 
FROM TicketVoiding_RequestDetailTicket_SubParlay tparlay WITH (NOLOCK)
	INNER JOIN bettrans14 b WITH (NOLOCK) ON b.transid = tparlay.transid
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid

*/

--DROP TABLE #tmp_batch
--DROP TABLE #tmp_bettrans
--DROP TABLE #tmp_table_list
--DROP TABLE #tmp_cust_scaleout

