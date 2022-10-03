/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Admin_CustLimitBet_CheckData_Job]
	@StartTime DATETIME OUTPUT,
	@EndTime DATETIME OUTPUT,
	@ErrorMessage VARCHAR(MAX) OUTPUT
AS
/*	
	Created: 20211111@Tina
    Task: Support check data for Max Payout Per Match setting - [Redmine: #158846]
    DB: DBTXN/bodb02
    Revisions:
		- 20211111@Tina: create
		- 20211210@Tina: remove code check "No ticket found on Queue" [Redmine: #159626]
		- 20220607@Tina: include checking data of testing currency
		- 20220809@Tina: include checking data for deposit - phase 3 [Redmine: #167898]
		- 20220906@Tina: Scale out DB - Check Ticket Data Consistency [Redmine: #175881]
		- 20221003@Victoria: Add list transid (top 100) to message [Redmine: #178536]

	Param's explanation:		
		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @SiteDBGroupID SMALLINT,
			@transId VARCHAR(MAX)

	SET @ErrorMessage = ''
	
	SET @StartTime   = DATEADD(MINUTE,-35,GETDATE())
	SET @EndTime   = DATEADD(MINUTE, -2,GETDATE())

	SET @transId = ''

	CREATE TABLE #RunningMatch (matchid INT PRIMARY KEY, sporttype SMALLINT)
	CREATE TABLE #NonSBRunningMatch (matchid INT PRIMARY KEY)

	SET @SiteDBGroupID = (SELECT dbo.f_Get_SiteDBGroupID())

	INSERT INTO #RunningMatch(matchid, sporttype)
	SELECT m.matchid, m.sporttype
	FROM dbo.[match] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND (m.sporttype <= 99 OR m.sporttype IN (164,180,186,190,191,192,193,194,195,196,197))
	UNION ALL
	SELECT 29 matchid, NULL sporttype

	INSERT INTO #NonSBRunningMatch(matchid)
	SELECT m.matchid
	FROM dbo.[match] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND m.sporttype > 99 AND m.sporttype NOT IN (164,180,186,190,191,192,193,194,195,196,197)

	----------------------------------------------------------Inserted data for excluded sporttype ---------------------------------------------------------
	IF EXISTS (SELECT TOP 1 1
				FROM dbo.CustLimitBet_789 cb WITH (NOLOCK)
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = cb.custid AND ci.[Site] = '789y'
					INNER JOIN #NonSBRunningMatch m ON cb.matchid = m.matchid
				WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
	BEGIN
		SET @ErrorMessage = '1. CustLimitBet_789 table is inserted data for excluded sporttype. ' + CHAR(13) + CHAR(10)
	END

	IF EXISTS (SELECT TOP 1 1
				FROM dbo.CustLimitBet_MBC cb WITH (NOLOCK)
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = cb.custid AND ci.[Site] <> '789y'
					INNER JOIN #NonSBRunningMatch m ON cb.matchid = m.matchid
				WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
	BEGIN
		SET @ErrorMessage =  @ErrorMessage + '1. CustLimitBet_MBC table is inserted data for excluded sporttype. ' + CHAR(13) + CHAR(10)
	END

	IF EXISTS (SELECT TOP 1 1
				FROM dbo.CustLimitBet_LIC cb WITH (NOLOCK)
					INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = cb.custid
					INNER JOIN #NonSBRunningMatch m ON cb.matchid = m.matchid
				WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
	BEGIN
		SET @ErrorMessage =  @ErrorMessage + '1. CustLimitBet_LIC table is inserted data for excluded sporttype. ' + CHAR(13) + CHAR(10)
	END
	
	-----------------------------------------------------History table is missing data--------------------------------------------------------------------
	--789y
	SELECT TOP (100) @transId = @transId + ',' + CAST(b.transId AS VARCHAR)
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] = '789y'
		INNER JOIN #RunningMatch m ON b.matchid = m.matchid 
	WHERE B.bettype NOT IN (10,2799,38,801,802,803,804,805,806) 
		AND NOT EXISTS(SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_789 h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
		AND b.transdate BETWEEN @StartTime AND @EndTime
		--AND ci.currency NOT IN (20,72)
		AND b.statusID NOT IN (101, 0)
		AND b.SiteDBGroupID = @SiteDBGroupID

	IF @transId <> ''
	BEGIN
		SET @transId = SUBSTRING(@transId, 2, LEN(@transId) - 1)
		SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_789 table is missing data. '  + CHAR(13) + CHAR(10) + '. Top 100 transId(s): ' + @transId
	END
	
	--MBC
	SET @transId = ''
	SELECT TOP (100) @transId = @transId + ',' + CAST(b.transId AS VARCHAR)
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] <> '789y'
		INNER JOIN #RunningMatch m ON b.matchid = m.matchid
	WHERE B.bettype NOT IN (10,2799,38,801,802,803,804,805,806)
		AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_MBC bh WITH (NOLOCK) WHERE bh.Matchid = b.matchid AND bh.transid = b.transid AND bh.CustID = b.custid)
		AND b.transdate BETWEEN @StartTime AND @EndTime
		--AND ci.currency NOT IN (20,72)
		AND b.statusID NOT IN (101, 0)
		AND NOT EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)
		AND b.SiteDBGroupID = @SiteDBGroupID
	
	IF @transId <> ''
	BEGIN
		SET @transId = SUBSTRING(@transId, 2, LEN(@transId) - 1)
		SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_MBC table is missing data. '  + CHAR(13) + CHAR(10) + '. Top 100 transId(s): ' + @transId
	END

	--LIC
	SET @transId = ''
	SELECT TOP (100) @transId = @transId + ',' + CAST(b.transId AS VARCHAR)
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN #RunningMatch m ON b.matchid = m.matchid
	WHERE B.bettype NOT IN (10,2799,38,801,802,803,804,805,806)
		AND NOT EXISTS (SELECT TOP 1 1 
						FROM dbo.CustLimitBetHistory_LIC bh WITH (NOLOCK) 
						WHERE bh.Matchid = b.matchid AND bh.transid = b.transid AND bh.CustID = b.custid
						)
		AND b.transdate BETWEEN @StartTime AND @EndTime
		AND b.statusID NOT IN (101, 0)
		AND EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend )
		AND b.SiteDBGroupID = @SiteDBGroupID

	IF @transId <> ''
	BEGIN
		SET @transId = SUBSTRING(@transId, 2, LEN(@transId) - 1)
		SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_LIC table is missing data. '  + CHAR(13) + CHAR(10) + '. Top 100 transId(s): ' + @transId
	END

	--789y
	SET @transId = ''
	SELECT TOP (100) @transId = @transId + ',' + CAST(b.transId AS VARCHAR)
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN dbo.outright O WITH (NOLOCK) ON b.matchid = o.orid
		INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] = '789y'
	WHERE B.bettype = 10
		AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_789 bh WITH (NOLOCK) WHERE bh.transid = b.transid AND bh.Matchid = b.matchid AND bh.CustID = b.custid)
		AND b.transdate BETWEEN @StartTime AND @EndTime
		--AND ci.currency NOT IN (20,72)
		AND b.SiteDBGroupID = @SiteDBGroupID

	IF @transId <> ''
	BEGIN
		SET @transId = SUBSTRING(@transId, 2, LEN(@transId) - 1)
		SET @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_789 table is missing data which EventTypeID = 2. '  + CHAR(13) + CHAR(10) + '. Top 100 transId(s): ' + @transId
	END
	
	--MBC
	SET @transId = ''
	SELECT TOP (100) @transId = @transId + ',' + CAST(b.transId AS VARCHAR)
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN dbo.outright O WITH (NOLOCK) ON b.matchid = o.orid
		INNER JOIN CustDB.dbo.vw_Customer ci WITH (NOLOCK) ON ci.custid = b.custid AND ci.[Site] <> '789y'
	WHERE B.bettype = 10
		AND NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_MBC bh WITH (NOLOCK) WHERE bh.Matchid = b.matchid AND bh.transid = b.transid AND bh.CustID = b.custid)
		AND NOT EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)
		AND b.transdate BETWEEN @StartTime AND @EndTime
		--AND ci.currency NOT IN (20,72)
		AND b.SiteDBGroupID = @SiteDBGroupID

	IF @transId <> ''
	BEGIN
		SET @transId = SUBSTRING(@transId, 2, LEN(@transId) - 1)
		SELECT TOP 1 @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_MBC table is missing data which EventTypeID = 2. '  + CHAR(13) + CHAR(10) + '. Top 100 transId(s): ' + @transId
	END

	--LIC
	SET @transId = ''
	SELECT TOP (100) @transId = @transId + ',' + CAST(b.transId AS VARCHAR)
	FROM dbo.bettrans b WITH (NOLOCK)
		INNER JOIN dbo.outright O WITH (NOLOCK) ON b.matchid = o.orid
	WHERE B.bettype = 10
		AND NOT EXISTS (SELECT TOP 1 1 
						FROM dbo.CustLimitBetHistory_LIC bh WITH (NOLOCK) 
						WHERE bh.Matchid = b.matchid AND bh.transid = b.transid AND bh.CustID = b.custid
						)
		AND EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)
		AND b.transdate BETWEEN @StartTime AND @EndTime
		--AND ci.currency NOT IN (20,72)
		AND b.SiteDBGroupID = @SiteDBGroupID

	IF @transId <> ''
	BEGIN
		SET @transId = SUBSTRING(@transId, 2, LEN(@transId) - 1)
		SELECT TOP 1 @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_LIC table is missing data which EventTypeID = 2. '  + CHAR(13) + CHAR(10) + '. Top 100 transId(s): ' + @transId
	END

	-------------------------check duplicate data in queue table for reject action --------------------------------------------------------------------

	--SELECT TOP 1 COUNT(1), q.ActionID, q.CustID, q.Matchid, q.EventTypeID, min(q.CreatedDate) MinDate , max (CreatedDate) MaxDate, q.Transids


	/*---20220607@Tina: For this case, waiting for TW fix this issue.
	IF EXISTS (SELECT TOP 1 1
				FROM dbo.CustLimitBetQueue Q with (nolock)
				WHERE q.ActionID = 2
					AND q.CreatedDate BETWEEN @StartTime AND @EndTime
				GROUP BY q.ActionID, q.CustID, q.Matchid, q.Transids, q.EventTypeID
				HAVING count(1) > 1
				ORDER BY q.Matchid)
	BEGIN
		SELECT TOP 1 @ErrorMessage = @ErrorMessage +  'Duplicate data in Queue table. ' + CHAR(13) + CHAR(10)
	END
	*/

	----------------------------------------------------------------------------------------------------------------------------------------------------

	CREATE TABLE #TempReject (transid BIGINT, checktime DATETIME, matchid int, custid INT, sporttype int)

	INSERT INTO #TempReject (transid, checktime, matchid, custid, sporttype)
	SELECT b.transid, b.checktime, b.matchid, b.custid, m.sporttype
	FROM dbo.bettrans b WITH (NOLOCK)        
			INNER JOIN #RunningMatch m ON b.matchid = m.matchid 
	WHERE b.statusID = 101
			AND b.transdate BETWEEN @StartTime AND @EndTime
			AND b.SiteDBGroupID = @SiteDBGroupID

	SET @transId = ''
	SELECT TOP (100) @transId = @transId + ',' + CAST(T.transId AS VARCHAR)
	FROM #TempReject T
	WHERE NOT EXISTS (SELECT TOP 1 1 
						FROM dbo.CustLimitBetQueue Q with (nolock)
						WHERE q.Matchid = T.matchid AND Q.ActionID = 2 AND Q.Transids like '%'+CONVERT(varchar, checktime, 120)+'%')

	IF @transId <> ''
	BEGIN
		SET @transId = SUBSTRING(@transId, 2, LEN(@transId) - 1)
		SET @ErrorMessage = @ErrorMessage + CHAR(13) + CHAR(10) + 'SP: Nap_Admin_CustLimitBet_CheckData_Job. Top 100 transId(s): ' + @transId
	END

	--SELECT CASE WHEN @ErrorMessage = '' THEN 'NO Error' ELSE @ErrorMessage END ErrorMessage, @StartTime StartTime, @EndTime EndTime

	DROP TABLE #TempReject
	DROP TABLE #RunningMatch
	DROP TABLE #NonSBRunningMatch
END