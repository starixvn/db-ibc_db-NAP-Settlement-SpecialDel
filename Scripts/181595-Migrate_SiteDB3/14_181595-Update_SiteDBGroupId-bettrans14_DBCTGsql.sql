/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-bodb02

	Revisions:
		- 20230626@Louisa: UPDATE sitedbgroupid = 3 for ticket of SITEDB3 at DBTRANS & ALL SubDB [Redmineid:#181595] 
		
*/

---Note : This script sitedbgroupid = 3 for table bettrans14

USE bodb02
GO

	CREATE TABLE #tmp_bettrans14_scaleout (rid INT IDENTITY (1,1) PRIMARY KEY,  transid BIGINT)
	CREATE TABLE #tmp_batch (transid BIGINT PRIMARY KEY)
	--------------------------------------------------------------
 
	-- bettrans14
	INSERT INTO #tmp_bettrans14_scaleout (transid)
	SELECT transid
	FROM bettrans14 b WITH (NOLOCK)
		INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 s WITH (NOLOCK) ON s.custid = b.custid
 
	DECLARE @StartRow INT = 1
		, @StopRow INT 
		, @MaxRow INT 
		, @Threshold INT = 2000 
		, @tablename VARCHAR (200)
		, @transIds VARCHAR (MAX) = ''
		, @siteDBGroupID SMALLINT = 3

	DECLARE @debug_message VARCHAR(500)

	------ 2. bettrans14 - #tmp_bettrans14_scaleout ------------
	IF EXISTS (SELECT TOP 1 1 FROM #tmp_bettrans14_scaleout)
	BEGIN 
		SET @tablename = 'bettrans14'
		SET @StartRow = 1		
		SET @MaxRow = (SELECT MAX(rid) FROM #tmp_bettrans14_scaleout)
		SET @StopRow = @Threshold

		WHILE (1 = 1)
		BEGIN

			TRUNCATE TABLE #tmp_batch

			DELETE R
			OUTPUT DELETED.transid
			INTO #tmp_batch (transid)		
			FROM #tmp_bettrans14_scaleout R
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

	DROp TABLE #tmp_batch
	DROP TABLE #tmp_bettrans14_scaleout


/*
------------ CHECKING DATA AFTER RUN SCRIPT -----------------------
 -- bettrans14
SELECT transid
FROM bettrans14 b WITH (NOLOCK)
	INNER JOIN SiteDBtmp.dbo.CustSiteDB3_20230626 s ON s.custid = b.custid
WHERE SiteDBGroupID = 0 OR SiteDBGroupID IS NULL
 
*/


