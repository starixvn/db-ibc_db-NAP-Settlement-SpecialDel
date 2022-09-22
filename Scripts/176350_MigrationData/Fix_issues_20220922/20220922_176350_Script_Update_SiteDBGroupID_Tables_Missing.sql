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
	DB: DBCTG-bodb02
	
	Revisions:
		- 	20220811@Helen: update sitedbgroupid [Redmine:#176350]
		-	20220922@Victoria: Add tables: zzbettrans, zzbettransm, TicketVoiding_RequestDetailTicket_Single, TicketVoiding_RequestDetailTicket_SubParlay

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

	IF EXISTS(SELECT 1 FROM sys.Objects WHERE  Object_id = OBJECT_ID(N'dbo.zzzbettrans'))
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettrans b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF EXISTS(SELECT 1 FROM sys.Objects WHERE  Object_id = OBJECT_ID(N'dbo.zzzbettransm'))
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.zzzbettransm b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF EXISTS(SELECT 1 FROM sys.Objects WHERE  Object_id = OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_Single'))
	BEGIN
		UPDATE b
			SET SiteDBGroupID = @SiteDBGroupID
		FROM	dbo.TicketVoiding_RequestDetailTicket_Single b WITH(ROWLOCK, UPDLOCK)
			INNER JOIN @tempTrans t ON b.transid = t.TransId
	END

	IF EXISTS(SELECT 1 FROM sys.Objects WHERE  Object_id = OBJECT_ID(N'dbo.TicketVoiding_RequestDetailTicket_SubParlay'))
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

CREATE TABLE #tmp_zzzbettrans_scaleout (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )
CREATE TABLE #tmp_zzzbettransm_scaleout (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )

CREATE TABLE #tmp_TicketVoiding_RequestDetailTicket_Single (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )
CREATE TABLE #tmp_TicketVoiding_RequestDetailTicket_SubParlay (transid BIGINT PRIMARY KEY, rid INT IDENTITY (1,1) )

CREATE TABLE #tmp_batch (transid BIGINT PRIMARY KEY)
--------------------------------------------------------------

--only licensees test were released on 25/08/2022
INSERT INTO #tmp_cust_scaleout (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('Athena000','SampleSite')

-------------------DATA PREPARATION --------------------------
-- zzzbettrans
INSERT INTO #tmp_zzzbettrans_scaleout (transid)
SELECT b.transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE b.SiteDBGroupID = 0

-- zzzbettrans
INSERT INTO #tmp_zzzbettrans_scaleout (transid)
SELECT b.transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN SiteDBtmp.dbo.zzzbettrans_20220922 s ON s.transid = b.transid

-- zzzbettransm
INSERT INTO #tmp_zzzbettransm_scaleout (transid)
SELECT b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN #tmp_cust_scaleout s ON s.custid = b.custid
WHERE b.SiteDBGroupID = 0

-- zzzbettransm
INSERT INTO #tmp_zzzbettransm_scaleout (transid)
SELECT b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN SiteDBtmp.dbo.zzzbettransm_20220922 s ON s.transid = b.transid

-- TicketVoiding_RequestDetailTicket_Single
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_Single (transid)
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_Single b WITH (NOLOCK)
	INNER JOIN SiteDBtmp.dbo.bettrans_20220922 s ON s.transid = b.transid AND s.matchid = b.MatchId

-- TicketVoiding_RequestDetailTicket_SubParlay
INSERT INTO #tmp_TicketVoiding_RequestDetailTicket_SubParlay (transid)
SELECT b.transid
FROM TicketVoiding_RequestDetailTicket_SubParlay b WITH (NOLOCK)
	INNER JOIN SiteDBtmp.dbo.bettransm_20220922 s ON s.transid = b.transid AND s.matchid = b.MatchId

---------------------- param declare to process data -----
DECLARE @StartRow INT = 1
	, @StopRow INT 
	, @MaxRow INT 
	, @Threshold INT = 2000 -- the number of each batch
	, @tablename VARCHAR (200)
	, @transIds VARCHAR (MAX) = ''
	, @siteDBGroupID SMALLINT = 1

DECLARE @debug_message VARCHAR(500)


------ 1. zzzbettrans - #tmp_zzzbettrans_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_zzzbettrans_scaleout)
BEGIN 
	SET @tablename = 'zzzbettrans'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_zzzbettrans_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_zzzbettrans_scaleout R
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

------ 2. zzzbettransm - #tmp_zzzbettransm_scaleout ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_zzzbettransm_scaleout)
BEGIN 
	SET @tablename = 'zzzbettransm'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_zzzbettransm_scaleout)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_zzzbettransm_scaleout R
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

------ 3. TicketVoiding_RequestDetailTicket_Single - #tmp_TicketVoiding_RequestDetailTicket_Single ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_TicketVoiding_RequestDetailTicket_Single)
BEGIN 
	SET @tablename = 'TicketVoiding_RequestDetailTicket_Single'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_TicketVoiding_RequestDetailTicket_Single)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_TicketVoiding_RequestDetailTicket_Single R
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

------ 4. TicketVoiding_RequestDetailTicket_SubParlay - #tmp_TicketVoiding_RequestDetailTicket_SubParlay ------------
IF EXISTS (SELECT TOP 1 1 FROM #tmp_TicketVoiding_RequestDetailTicket_SubParlay)
BEGIN 
	SET @tablename = 'TicketVoiding_RequestDetailTicket_SubParlay'
	SET @StartRow = 1	
	SET @MaxRow = (SELECT MAX(rid) FROM #tmp_TicketVoiding_RequestDetailTicket_SubParlay)
	SET @StopRow = @Threshold

	WHILE (1 = 1)
	BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		TRUNCATE TABLE #tmp_batch

		DELETE R
		OUTPUT DELETED.transid
		INTO #tmp_batch (transid)		
		FROM #tmp_TicketVoiding_RequestDetailTicket_SubParlay R
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

