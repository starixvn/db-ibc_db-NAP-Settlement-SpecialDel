/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="" isFunction="0"></info>*/
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
		- 20230216@Tina: enable to check duplicate data in queue table for reject action [Redmine: #183838]
		- 20230317@Max: Database - Revise the Reject Main Parlay Ticket (Max Payout Per Match) [Redmine: #184559]
		- 20230321@Max: Enhance performance & Change to use Sitelabel for 789y [Redmine: #184559]
		- 20230516@Tina: Database - Improve Max payout detection (SQL Jobs) [Redmine: #188130]
		- 20230712@Max: Scale out credit [Redmine: #181595]
		- 20230905@Louisa: Support Max Payout for VS3 [Redmine:#193562]
		- 20240607@Max: Max Turnover/Payout Job detection (the current job) [Redmine: #206245]

	Param's explanation:		
		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @SiteDBGroupID SMALLINT,
			@transIds VARCHAR(MAX),
			@UUSTransIds VARCHAR(MAX),
			@CRLF CHAR(2)

	SET @ErrorMessage = ''
	
	SET @StartTime   = DATEADD(MINUTE,-35,GETDATE())
	SET @EndTime   = DATEADD(MINUTE, -2,GETDATE())
	SET @CRLF = CHAR(13)+CHAR(10)

	SET @transIds = ''
	SET @UUSTransIds = ''

	CREATE TABLE #RunningMatch (matchid INT PRIMARY KEY, sporttype SMALLINT)
	CREATE TABLE #NonSBRunningMatch (matchid INT PRIMARY KEY)

	CREATE TABLE #Result_tmp (Transid BIGINT, matchid INT, custid INT, Currency TINYINT)

	SET @SiteDBGroupID = (SELECT dbo.f_Get_SiteDBGroupID())

	INSERT INTO #RunningMatch(matchid, sporttype)
	SELECT m.matchid, m.sporttype
	FROM dbo.[match] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND (m.sporttype <= 99 OR m.sporttype IN (164,178,179,180,186,190,191,192,193,194,195,196,197))
	UNION ALL
	SELECT 29 matchid, NULL sporttype

	INSERT INTO #NonSBRunningMatch(matchid)
	SELECT m.matchid
	FROM dbo.[match] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND m.sporttype > 99 AND m.sporttype NOT IN (164,178,179,180,186,190,191,192,193,194,195,196,197)

	----------------------------------------------------------Inserted data for excluded sporttype ---------------------------------------------------------
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		IF EXISTS (SELECT TOP 1 1
					FROM dbo.CustLimitBet_789 cb WITH (NOLOCK)
						INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = cb.custid
						INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = ci.site AND ISNULL(s.SiteLabel,'') = '789y'
						INNER JOIN #NonSBRunningMatch m ON cb.matchid = m.matchid
					WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
		BEGIN
			SET @ErrorMessage = '1. CustLimitBet_789 table is inserted data for excluded sporttype.' + @CRLF 
		END
	END

	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		IF EXISTS (SELECT TOP 1 1
					FROM dbo.CustLimitBet_MBC cb WITH (NOLOCK)
						INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = cb.custid
						INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = ci.site AND ISNULL(s.SiteLabel,'') <> '789y'
						INNER JOIN #NonSBRunningMatch m ON cb.matchid = m.matchid
					WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
		BEGIN
			SET @ErrorMessage =  @ErrorMessage + '1. CustLimitBet_MBC table is inserted data for excluded sporttype. ' + @CRLF 
		END
	END

	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		IF EXISTS (SELECT TOP 1 1
					FROM dbo.CustLimitBet_LIC cb WITH (NOLOCK)
						INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = cb.custid
						INNER JOIN #NonSBRunningMatch m ON cb.matchid = m.matchid
					WHERE cb.ModifiedDate BETWEEN @StartTime AND @EndTime)
		BEGIN
			SET @ErrorMessage =  @ErrorMessage + '1. CustLimitBet_LIC table is inserted data for excluded sporttype. ' + @CRLF 
		END
	END
	
	-----------------------------------------------------History table is missing data--------------------------------------------------------------------
	--789y
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		SET @transIds = ''
		SET @UUSTransIds = ''
		TRUNCATE TABLE #Result_tmp
		INSERT INTO #Result_tmp (matchid, Transid, custid, Currency)
		SELECT TOP (100) m.matchid, tmp.transId, tmp.custid, tmp.currency
		FROM #RunningMatch m
			CROSS APPLY (
					SELECT TOP 100 b.transid, b.custid, b.currency 
					FROM dbo.bettrans b WITH (NOLOCK)
						INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = b.custid
						INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = ci.site AND ISNULL(s.SiteLabel,'') = '789y'
						LEFT JOIN dbo.CustLimitBetHistory_789 h WITH (NOLOCK) ON h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid
					WHERE b.matchid = m.matchid 
						AND h.Transid IS NULL
						AND b.statusID NOT IN (101, 0)
						AND b.bettype NOT IN (10,2799,38,801,802,803,804,805,806) 
						AND b.transdate BETWEEN @StartTime AND @EndTime
						AND b.SiteDBGroupID = @SiteDBGroupID
			) AS tmp
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_789 h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency <> 20
			) AS tmp
		
			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_789 h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency = 20
			) AS tmp
		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_789 table is missing data for real currency. Top 100 transId(s): ' + @transIds + @CRLF
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_789 table is missing data for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF 
		END
	END
	
	--MBC
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		SET @transIds = ''
		SET @UUSTransIds = ''
		TRUNCATE TABLE #Result_tmp
		INSERT INTO #Result_tmp (matchid, Transid, custid, Currency)
		SELECT TOP (100) m.matchid, tmp.transId, tmp.custid, tmp.currency
		FROM #RunningMatch m
			CROSS APPLY (
					SELECT TOP 100 b.transid, b.custid, b.currency 
					FROM dbo.bettrans b WITH (NOLOCK)
						INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = b.custid
						INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = ci.site AND ISNULL(s.SiteLabel,'') <> '789y'
						LEFT JOIN dbo.CustLimitBetHistory_MBC h WITH (NOLOCK) ON h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid
					WHERE b.matchid = m.matchid 
						AND h.Transid IS NULL
						AND b.statusID NOT IN (101, 0)
						AND b.bettype NOT IN (10,2799,38,801,802,803,804,805,806) 
						AND b.transdate BETWEEN @StartTime AND @EndTime
						AND b.SiteDBGroupID = @SiteDBGroupID
						AND NOT EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)
			) AS tmp

		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_MBC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency <> 20
			) AS tmp
		
			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_MBC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency = 20
			) AS tmp
		END
	
		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_MBC table is missing data for real currency. Top 100 transId(s): ' + @transIds + @CRLF 
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_MBC table is missing data for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF 
		END
	END

	--LIC
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		SET @transIds = ''
		SET @UUSTransIds = ''
		TRUNCATE TABLE #Result_tmp
		INSERT INTO #Result_tmp (matchid, Transid, custid, Currency)
		SELECT TOP (100) m.matchid, tmp.transId, tmp.custid, tmp.currency
		FROM #RunningMatch m
			CROSS APPLY (
					SELECT TOP 100 b.transid, b.custid, b.currency 
					FROM dbo.bettrans b WITH (NOLOCK)
						LEFT JOIN dbo.CustLimitBetHistory_LIC h WITH (NOLOCK) ON h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid
					WHERE b.matchid = m.matchid 
						AND h.Transid IS NULL
						AND b.statusID NOT IN (101, 0)
						AND b.bettype NOT IN (10,2799,38,801,802,803,804,805,806) 
						AND b.transdate BETWEEN @StartTime AND @EndTime
						AND b.SiteDBGroupID = @SiteDBGroupID
						AND EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend )
			) AS tmp

		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_LIC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency <> 20
			) AS tmp	

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_LIC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency = 20
			) AS tmp	
		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_LIC table is missing data for real currency. Top 100 transId(s): ' + @transIds + @CRLF 
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustLimitBetHistory_LIC table is missing data for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF 
		END
	END

	--789y
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		SET @transIds = ''
		SET @UUSTransIds = ''
		TRUNCATE TABLE #Result_tmp
		INSERT INTO #Result_tmp (matchid, Transid, custid, Currency)
		SELECT TOP (100) b.matchid, b.transId, b.custid, b.currency
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.outright O WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = b.custid
			INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = ci.site AND ISNULL(s.SiteLabel,'') = '789y'
			LEFT JOIN dbo.CustLimitBetHistory_789 h WITH (NOLOCK) ON h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid
		WHERE b.bettype = 10
			AND h.Transid IS NULL
			AND b.transdate BETWEEN @StartTime AND @EndTime
			AND b.SiteDBGroupID = @SiteDBGroupID

		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_789 h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency <> 20
			) AS tmp	

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_789 h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency = 20
			) AS tmp	
		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_789 table is missing data which EventTypeID = 2 for real currency. Top 100 transId(s): ' + @transIds + @CRLF
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_789 table is missing data which EventTypeID = 2 for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF
		END
	END
	
	--MBC
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		SET @transIds = ''
		SET @UUSTransIds = ''
		TRUNCATE TABLE #Result_tmp
		INSERT INTO #Result_tmp (matchid, Transid, custid, Currency)
		SELECT TOP (100) b.matchid, b.transId, b.custid, b.currency
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.outright O WITH (NOLOCK) ON b.matchid = o.orid
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = b.custid
			INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON s.site = ci.site AND ISNULL(s.SiteLabel,'') <> '789y'
			LEFT JOIN dbo.CustLimitBetHistory_MBC h WITH (NOLOCK) ON h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid
		WHERE b.bettype = 10
			AND h.Transid IS NULL
			AND b.transdate BETWEEN @StartTime AND @EndTime
			AND b.SiteDBGroupID = @SiteDBGroupID
			AND NOT EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)

		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_MBC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency <> 20
			) AS tmp
		
			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_MBC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency = 20
			) AS tmp
		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SELECT TOP 1 @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_MBC table is missing data which EventTypeID = 2 for real currency. Top 100 transId(s): ' + @transIds + @CRLF 
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SELECT TOP 1 @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_MBC table is missing data which EventTypeID = 2 for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF 
		END
	END

	--LIC
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		SET @transIds = ''
		SET @UUSTransIds = ''
		TRUNCATE TABLE #Result_tmp
		INSERT INTO #Result_tmp (matchid, Transid, custid, Currency)
		SELECT TOP (100) b.matchid, b.transId, b.custid, b.currency
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN dbo.outright O WITH (NOLOCK) ON b.matchid = o.orid
			LEFT JOIN dbo.CustLimitBetHistory_LIC h WITH (NOLOCK) ON h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid
		WHERE b.bettype = 10
			AND h.Transid IS NULL
			AND b.transdate BETWEEN @StartTime AND @EndTime
			AND b.SiteDBGroupID = @SiteDBGroupID
			AND EXISTS (SELECT 1 FROM CustDb.dbo.Dep_CustSuper ds WITH (NOLOCK) WHERE ds.custid = b.srecommend)

		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_LIC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency <> 20
			) AS tmp
		
			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId, b.custid, b.matchid
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustLimitBetHistory_LIC h WITH (NOLOCK) WHERE h.Matchid = b.matchid AND h.transid = b.transid AND h.CustID = b.custid)
					AND b.Currency = 20
			) AS tmp
		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SELECT TOP 1 @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_LIC table is missing data which EventTypeID = 2 for real currency. Top 100 transId(s): ' + @transIds + @CRLF 
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SELECT TOP 1 @ErrorMessage = @ErrorMessage + '3. CustLimitBetHistory_LIC table is missing data which EventTypeID = 2 for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF
		END
	END

	-------------------------check duplicate data in queue table for reject action --------------------------------------------------------------------

	--SELECT TOP 1 COUNT(1), q.ActionID, q.CustID, q.Matchid, q.EventTypeID, min(q.CreatedDate) MinDate , max (CreatedDate) MaxDate, q.Transids

	IF EXISTS (SELECT TOP 1 1
				FROM dbo.CustLimitBetQueue Q with (nolock)
				WHERE q.ActionID = 2
					AND q.CreatedDate BETWEEN @StartTime AND @EndTime
				GROUP BY q.ActionID, q.CustID, q.Matchid, q.Transids, q.EventTypeID
				HAVING count(1) > 1
				)
	BEGIN
		SELECT TOP 1 @ErrorMessage = @ErrorMessage +  '4. Duplicate data in Queue table. ' + @CRLF
	END

	----------------------------------------------------------------------------------------------------------------------------------------------------

	CREATE TABLE #TempReject (transid BIGINT, checktime DATETIME, matchid int, custid INT, sporttype int, currency tinyint)

	INSERT INTO #TempReject (transid, checktime, matchid, custid, sporttype, currency)
	SELECT b.transid, b.checktime, b.matchid, b.custid, m.sporttype, b.currency
	FROM dbo.bettrans b WITH (NOLOCK)        
			INNER JOIN #RunningMatch m ON b.matchid = m.matchid 
	WHERE b.statusID = 101
			AND b.transdate BETWEEN @StartTime AND @EndTime
			AND b.SiteDBGroupID = @SiteDBGroupID

	SET @transIds = ''
	SET @UUSTransIds = ''
	SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
	FROM
		(SELECT TOP (100) T.transId
		FROM #TempReject T
		WHERE NOT EXISTS (SELECT TOP 1 1 
							FROM dbo.CustLimitBetQueue Q with (nolock)
							WHERE q.Matchid = T.matchid AND Q.ActionID = 2 AND Q.Transids like '%'+CONVERT(varchar, checktime, 121)+'%'								
						)
			AND t.matchid <> 29
			AND t.currency <> 20
						) AS tmp

	SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
	FROM
		(SELECT TOP (100) T.transId
		FROM #TempReject T
		WHERE NOT EXISTS (SELECT TOP 1 1 
							FROM dbo.CustLimitBetQueue Q with (nolock)
							WHERE q.Matchid = T.matchid AND Q.ActionID = 2 AND Q.Transids like '%'+CONVERT(varchar, checktime, 121)+'%'								
						)
			AND t.matchid <> 29
			AND t.currency = 20
						) AS tmp

	IF ISNULL(@transIds,'') <> ''
	BEGIN
		SET @ErrorMessage = @ErrorMessage  + @CRLF + '5. Missing reject tickets in queue for Single for real currency. Top 100 transId(s): ' + @transIds + @CRLF
	END

	IF ISNULL(@UUStransIds,'') <> ''
	BEGIN
		SET @ErrorMessage = @ErrorMessage  + @CRLF + '5. Missing reject tickets in queue for Single for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF
	END

	SET @transIds = ''
	SET @UUSTransIds = ''
	SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
	FROM
		(SELECT TOP (100) T.transId
		FROM #TempReject T
		WHERE NOT EXISTS (SELECT TOP 1 1 
							FROM dbo.CustLimitBetQueue Q with (nolock)
							WHERE q.Matchid = T.matchid AND Q.ActionID = 2 
							AND (
								-- parlay new format
								(Q.Transids like '%'+CONVERT(VARCHAR(20), T.transid)+'%' AND Q.Transids NOT LIKE '%rejectTicket%') 
								)							
							)
				AND t.Matchid = 29
				AND t.currency <> 20
		) AS tmp

	SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
	FROM
		(SELECT TOP (100) T.transId
		FROM #TempReject T
		WHERE NOT EXISTS (SELECT TOP 1 1 
							FROM dbo.CustLimitBetQueue Q with (nolock)
							WHERE q.Matchid = T.matchid AND Q.ActionID = 2 
							AND (
								-- parlay new format
								(Q.Transids like '%'+CONVERT(VARCHAR(20), T.transid)+'%' AND Q.Transids NOT LIKE '%rejectTicket%') 
								)							
							)
				AND t.Matchid = 29
				AND t.currency = 20
		) AS tmp

	IF ISNULL(@transIds,'') <> ''
	BEGIN
		SET @ErrorMessage = @ErrorMessage  + @CRLF + '6. Missing reject tickets in queue for Parlay for real currency. Top 100 transId(s): ' + @transIds + @CRLF
	END

	IF ISNULL(@UUStransIds,'') <> ''
	BEGIN
		SET @ErrorMessage = @ErrorMessage  + @CRLF + '6. Missing reject tickets in queue for Parlay for UUS currency. Top 100 transId(s): ' + @UUStransIds + @CRLF
	END

	--------------Rule to check negative amount for all eventtypeid (not for phone betting) --------------------
	DECLARE @CustIDs VARCHAR(MAX) = ''
	DECLARE @UUSCustIDs VARCHAR(MAX) = ''
	DECLARE @EventtypeIDs VARCHAR(1000) = ''

	CREATE TABLE #Result_Negative_tmp (custid INT,currency TINYINT, eventtypeid TINYINT )

	SET @StartTime   = DATEADD(MINUTE,-35,GETDATE())
	SET @EndTime   = DATEADD(MINUTE, -2,GETDATE())
	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_789 -------------------------
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,3,4,5'
		
		TRUNCATE TABLE #Result_Negative_tmp

		INSERT INTO #Result_Negative_tmp (custid, Currency,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid, ci.currency,l.EventTypeID
		FROM CustLimitBet_789 l WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = l.custid
			CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID AND b.betfrom <> 'p'
						 ) AS tmp
		WHERE l.AccumTurnover < 0 AND l.ModifiedDate BETWEEN @StartTime AND @EndTime
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '7. CustLimitBet_789 table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '7. CustLimitBet_789 table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END
	
	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_MBC -------------------------
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,3,4,5'
		
		TRUNCATE TABLE #Result_Negative_tmp
		INSERT INTO #Result_Negative_tmp (custid, Currency,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid, ci.currency,l.EventTypeID
		FROM CustLimitBet_MBC l WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = l.custid
			CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID AND b.betfrom <> 'p'
						 ) AS tmp
		WHERE l.AccumTurnover < 0 AND l.ModifiedDate BETWEEN @StartTime AND @EndTime
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '7. CustLimitBet_MBC table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '7. CustLimitBet_MBC table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END

	-------7. Alert when having negative amount for all eventtypeid: CustLimitBet_LIC -------------------------
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,3,4,5'
		
		TRUNCATE TABLE #Result_Negative_tmp
		INSERT INTO #Result_Negative_tmp (custid, Currency,eventtypeid)
		SELECT DISTINCT TOP (100) l.custid, ci.currency,l.EventTypeID
		FROM CustLimitBet_LIC l WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON ci.custid = l.custid
			CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK)
						 WHERE b.matchid = l.Matchid AND b.custid = l.CustID AND b.betfrom <> 'p'
						 ) AS tmp
		WHERE l.AccumTurnover < 0 AND l.ModifiedDate BETWEEN @StartTime AND @EndTime
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '7. CustLimitBet_LIC table contains negative amount for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT b.custid
				FROM #Result_Negative_tmp b 
				WHERE b.Currency = 20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '7. CustLimitBet_LIC table contains negative amount for UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END

	--------------Rule to data mismatch --------------------
	SET @StartTime   = DATEADD(MINUTE,-35,GETDATE())
	SET @EndTime   = DATEADD(MINUTE, -2,GETDATE())

	CREATE TABLE #Result_Mismatch_tmp (custid INT,currency TINYINT, eventtypeid TINYINT, AccumTurnover MONEY, AccumPayout MONEY, matchid INT )
	CREATE TABLE #CustLimitBet_tmp  (Matchid INT, CustID INT, EventTypeID TINYINT, AccumTurnover MONEY, AccumPayout MONEY)
	CREATE TABLE #Final (custid INT,currency TINYINT, eventtypeid TINYINT, matchid INT)
	-------8. CustLimitBet_789: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_789 tables -------------------------
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '3,4'
		
		TRUNCATE TABLE #Result_Mismatch_tmp
		TRUNCATE TABLE #CustLimitBet_tmp
		TRUNCATE TABLE #Final

		INSERT INTO #CustLimitBet_tmp (matchid, custid, eventtypeid, accumTurnover, accumPayout)
		SELECT  t.Matchid,t.CustID, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_789 t WITH(NOLOCK)
		WHERE t.EventTypeID IN (3,4) AND t.Matchid = 29
			AND t.ModifiedDate BETWEEN @StartTime AND @EndTime

		;WITH cte AS
		(
			SELECT custid, EventTypeID, SUM(PayoutAdjust) as Payout_Accum, SUM(TurnoverAdjust) as Turnover_Accum
			FROM (
					SELECT h.transid, b.custid, h.EventTypeID
						, MAX(h.PayoutAdjust) as PayoutAdjust
						, MAX(h.TurnoverAdjust) as TurnoverAdjust
					FROM dbo.bettrans b WITH (NOLOCK) 
						INNER JOIN #CustLimitBet_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
						INNER JOIN dbo.CustLimitBetHistory_789 h WITH(NOLOCK)
							ON h.Transid = b.transid AND b.custid = h.CustID AND h.Matchid = b.matchid
					WHERE b.ruben = 0
						AND h.Matchid = 29 
						AND b.oddsid IN (1,99)
						AND b.betfrom <> 'p'
					GROUP BY h.transid,b.custid, h.EventTypeID
				) AS tmp
		)
		INSERT INTO #Result_Mismatch_tmp (custid, Currency,eventtypeid, AccumTurnover, AccumPayout)
		SELECT TOP (100) t.CustID, cm.currency, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_789 t WITH(NOLOCK)
			INNER JOIN CUSTDB.dbo.Customer cm WITH (NOLOCK) ON t.CustID = cm.custid
			CROSS APPLY (SELECT	TOP 1 1 IsInvalid
						 FROM cte c
						 WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID
								AND ( c.Turnover_Accum <> t.AccumTurnover OR c.Payout_Accum <> t.AccumPayout)
								) AS tmp
		WHERE t.matchid = 29
			 AND t.EventTypeID IN (3,4)
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:03.000'
			;WITH cte AS
			(
				SELECT custid, EventTypeID, SUM(PayoutAdjust) as Payout_Accum, SUM(TurnoverAdjust) as Turnover_Accum
				FROM (
						SELECT h.transid, b.custid, h.EventTypeID
							, MAX(h.PayoutAdjust) as PayoutAdjust
							, MAX(h.TurnoverAdjust) as TurnoverAdjust
						FROM dbo.bettrans b WITH (NOLOCK) 
							INNER JOIN #Result_Mismatch_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
							INNER JOIN dbo.CustLimitBetHistory_789 h WITH(NOLOCK)
								ON h.Transid = b.transid AND b.custid = h.CustID AND h.Matchid = b.matchid
						WHERE b.ruben = 0
							AND h.Matchid = 29 
							AND b.oddsid IN (1,99)
							AND b.betfrom <> 'p'
						GROUP BY h.transid,b.custid, h.EventTypeID
					) AS tmp
			)
			INSERT INTO #Final (custid, Currency,eventtypeid)
			SELECT DISTINCT TOP (100) t.CustID, t.currency, t.EventTypeID
			FROM #Result_Mismatch_tmp t WITH(NOLOCK)
					INNER JOIN dbo.CustLimitBet_789 l WITH(NOLOCK) ON t.custid = l.CustID AND t.matchid = l.Matchid AND t.eventtypeid = l.EventTypeID
					CROSS APPLY (SELECT	TOP 1 1 IsInvalid
									FROM cte c
									WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID 
										AND ( c.Turnover_Accum <> l.AccumTurnover OR c.Payout_Accum <> l.AccumPayout)
										) AS tmp

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_789: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_789 tables for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT t.CustID
				FROM #Final t
				WHERE t.currency =  20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_789: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_789 tables UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END
	
	-------8. CustLimitBet_mbc: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_mbc tables -------------------------
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '3,4'
		
		TRUNCATE TABLE #Result_Mismatch_tmp
		TRUNCATE TABLE #CustLimitBet_tmp
		TRUNCATE TABLE #Final

		INSERT INTO #CustLimitBet_tmp (matchid, custid, eventtypeid, accumTurnover, accumPayout)
		SELECT  t.Matchid,t.CustID, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_MBC t WITH(NOLOCK)
		WHERE t.EventTypeID IN (3,4) AND t.Matchid = 29
			AND t.ModifiedDate BETWEEN @StartTime AND @EndTime

		;WITH cte AS
		(
			SELECT custid, EventTypeID, SUM(PayoutAdjust) as Payout_Accum, SUM(TurnoverAdjust) as Turnover_Accum
			FROM (
					SELECT h.transid, b.custid, h.EventTypeID
						, MAX(h.PayoutAdjust) as PayoutAdjust
						, MAX(h.TurnoverAdjust) as TurnoverAdjust
					FROM dbo.bettrans b WITH (NOLOCK) 
						INNER JOIN #CustLimitBet_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
						INNER JOIN dbo.CustLimitBetHistory_MBC h WITH(NOLOCK)
							ON h.Transid = b.transid AND b.custid = h.CustID AND h.Matchid = b.matchid
					WHERE b.ruben = 0
						AND h.Matchid = 29 
						AND b.oddsid IN (1,99)
						AND b.betfrom <> 'p'
					GROUP BY h.transid,b.custid, h.EventTypeID
				) AS tmp
		)
		INSERT INTO #Result_Mismatch_tmp (custid, Currency,eventtypeid, AccumTurnover, AccumPayout)
		SELECT TOP (100) t.CustID, cm.currency, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_MBC t WITH(NOLOCK)
			INNER JOIN CUSTDB.dbo.Customer cm WITH (NOLOCK) ON t.CustID = cm.custid
			CROSS APPLY (SELECT	TOP 1 1 IsInvalid
						 FROM cte c
						 WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID
								AND ( c.Turnover_Accum <> t.AccumTurnover OR c.Payout_Accum <> t.AccumPayout)
								) AS tmp
		WHERE t.matchid = 29
			 AND t.EventTypeID IN (3,4)
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:03.000'
			;WITH cte AS
			(
				SELECT custid, EventTypeID, SUM(PayoutAdjust) as Payout_Accum, SUM(TurnoverAdjust) as Turnover_Accum
				FROM (
						SELECT h.transid, b.custid, h.EventTypeID
							, MAX(h.PayoutAdjust) as PayoutAdjust
							, MAX(h.TurnoverAdjust) as TurnoverAdjust
						FROM dbo.bettrans b WITH (NOLOCK) 
							INNER JOIN #Result_Mismatch_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
							INNER JOIN dbo.CustLimitBetHistory_MBC h WITH(NOLOCK)
								ON h.Transid = b.transid AND b.custid = h.CustID AND h.Matchid = b.matchid
						WHERE b.ruben = 0
							AND h.Matchid = 29 
							AND b.oddsid IN (1,99)
							AND b.betfrom <> 'p'
						GROUP BY h.transid,b.custid, h.EventTypeID
					) AS tmp
			)
			INSERT INTO #Final (custid, Currency,eventtypeid)
			SELECT DISTINCT TOP (100) t.CustID, t.currency, t.EventTypeID
			FROM #Result_Mismatch_tmp t WITH(NOLOCK)
					INNER JOIN dbo.CustLimitBet_MBC l WITH(NOLOCK) ON t.custid = l.CustID AND t.matchid = l.Matchid AND t.eventtypeid = l.EventTypeID
					CROSS APPLY (SELECT	TOP 1 1 IsInvalid
									FROM cte c
									WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID 
										AND ( c.Turnover_Accum <> l.AccumTurnover OR c.Payout_Accum <> l.AccumPayout)
										) AS tmp

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_MBC: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_MBC tables for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT t.CustID
				FROM #Final t
				WHERE t.currency =  20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_MBC: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_MBC tables UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END

	-------8. CustLimitBet_mbc: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_LIC tables -------------------------
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '3,4'
		
		TRUNCATE TABLE #Result_Mismatch_tmp
		TRUNCATE TABLE #CustLimitBet_tmp
		TRUNCATE TABLE #Final

		INSERT INTO #CustLimitBet_tmp (matchid, custid, eventtypeid, accumTurnover, accumPayout)
		SELECT  t.Matchid,t.CustID, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_LIC t WITH(NOLOCK)
		WHERE t.EventTypeID IN (3,4) AND t.Matchid = 29
			AND t.ModifiedDate BETWEEN @StartTime AND @EndTime

		;WITH cte AS
		(
			SELECT custid, EventTypeID, SUM(PayoutAdjust) as Payout_Accum, SUM(TurnoverAdjust) as Turnover_Accum
			FROM (
					SELECT h.transid, b.custid, h.EventTypeID
						, MAX(h.PayoutAdjust) as PayoutAdjust
						, MAX(h.TurnoverAdjust) as TurnoverAdjust
					FROM dbo.bettrans b WITH (NOLOCK) 
						INNER JOIN #CustLimitBet_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
						INNER JOIN dbo.CustLimitBetHistory_LIC h WITH(NOLOCK)
							ON h.Transid = b.transid AND b.custid = h.CustID AND h.Matchid = b.matchid
					WHERE b.ruben = 0
						AND h.Matchid = 29 
						AND b.oddsid IN (1,99)
						AND b.betfrom <> 'p'
					GROUP BY h.transid,b.custid, h.EventTypeID
				) AS tmp
		)
		INSERT INTO #Result_Mismatch_tmp (custid, Currency,eventtypeid, AccumTurnover, AccumPayout)
		SELECT TOP (100) t.CustID, cm.currency, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_LIC t WITH(NOLOCK)
			INNER JOIN CUSTDB.dbo.Customer cm WITH (NOLOCK) ON t.CustID = cm.custid
			CROSS APPLY (SELECT	TOP 1 1 IsInvalid
						 FROM cte c
						 WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID
								AND ( c.Turnover_Accum <> t.AccumTurnover OR c.Payout_Accum <> t.AccumPayout)
								) AS tmp
		WHERE t.matchid = 29
			 AND t.EventTypeID IN (3,4)
	
		IF @@ROWCOUNT > 0
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:03.000'
			;WITH cte AS
			(
				SELECT custid, EventTypeID, SUM(PayoutAdjust) as Payout_Accum, SUM(TurnoverAdjust) as Turnover_Accum
				FROM (
						SELECT h.transid, b.custid, h.EventTypeID
							, MAX(h.PayoutAdjust) as PayoutAdjust
							, MAX(h.TurnoverAdjust) as TurnoverAdjust
						FROM dbo.bettrans b WITH (NOLOCK) 
							INNER JOIN #Result_Mismatch_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
							INNER JOIN dbo.CustLimitBetHistory_LIC h WITH(NOLOCK)
								ON h.Transid = b.transid AND b.custid = h.CustID AND h.Matchid = b.matchid
						WHERE b.ruben = 0
							AND h.Matchid = 29 
							AND b.oddsid IN (1,99)
							AND b.betfrom <> 'p'
						GROUP BY h.transid,b.custid, h.EventTypeID
					) AS tmp
			)
			INSERT INTO #Final (custid, Currency,eventtypeid)
			SELECT DISTINCT TOP (100) t.CustID, t.currency, t.EventTypeID
			FROM #Result_Mismatch_tmp t WITH(NOLOCK)
					INNER JOIN dbo.CustLimitBet_LIC l WITH(NOLOCK) ON t.custid = l.CustID AND t.matchid = l.Matchid AND t.eventtypeid = l.EventTypeID
					CROSS APPLY (SELECT	TOP 1 1 IsInvalid
									FROM cte c
									WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID 
										AND ( c.Turnover_Accum <> l.AccumTurnover OR c.Payout_Accum <> l.AccumPayout)
										) AS tmp

			SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency <> 20
			) AS tmp

			IF ISNULL(@CustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_LIC: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_LIC tables for real currency. Top 100 custid(s): ' + @CustIDs + ' Eventtypeid(s): '+@EventtypeIDs + @CRLF
			----------------uus------------------------
			SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
			FROM(
				SELECT DISTINCT t.CustID
				FROM #Final t
				WHERE t.currency =  20
			) AS tmp

			IF ISNULL(@UUSCustIDs,'') <> ''
				SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_LIC: Parlay contains data mismatch with bettrans vs CustLimitBetHistory_LIC tables UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ' Eventtypeid(s): '+ @EventtypeIDs + @CRLF
		END
	END

	--------------Rule to check Eventtypeid 1,2,5 contains data mismatch --------------------
	DECLARE @matchIDs  VARCHAR(MAX) = ''
	DECLARE @UUSmatchIDs  VARCHAR(MAX) = ''
	DECLARE @UUSEventtypeIDs VARCHAR(1000) = ''

	SET @StartTime   = DATEADD(MINUTE,-35,GETDATE())
	SET @EndTime   = DATEADD(MINUTE, -2,GETDATE())

	-------8. CustLimitBet_789: Eventtypeid 1,2,5 contains data mismatch with bettrans vs CustLimitBetHistory_789 tables -------------------------
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,5'
		
		TRUNCATE TABLE #Result_Mismatch_tmp
		TRUNCATE TABLE #CustLimitBet_tmp
		TRUNCATE TABLE #Final

		INSERT INTO #CustLimitBet_tmp (matchid, custid, eventtypeid, accumTurnover, accumPayout)
		SELECT  t.Matchid,t.CustID, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_789 t WITH(NOLOCK)
		WHERE t.EventTypeID IN (1,2,5) AND t.Matchid <> 29
			AND t.ModifiedDate BETWEEN @StartTime AND @EndTime
		
		IF @@ROWCOUNT > 0
		BEGIN
			;WITH cte
			AS (
				SELECT b.custid,b.matchid,tmp.EventTypeID
					, SUM (PayoutAdjust) as Payout_Accum
					, SUM(TurnoverAdjust) as Turnover_Accum
				FROM bettrans b WITH (NOLOCK) 
					INNER JOIN #CustLimitBet_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
					CROSS APPLY ( SELECT TOP 1 h.EventTypeID
											, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.PayoutAdjust)	END AS PayoutAdjust
											, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.TurnoverAdjust) END AS TurnoverAdjust
									FROM CustLimitBetHistory_789 h WITH(NOLOCK)
									WHERE h.Transid = b.transid 
										AND h.EventTypeID = m.EventTypeID
									) AS tmp
				WHERE b.betfrom <> 'p'				
				GROUP BY b.custid,b.matchid,tmp.EventTypeID
			)

			INSERT INTO #Result_Mismatch_tmp (custid, Currency,eventtypeid, AccumTurnover, AccumPayout, matchid)
			SELECT TOP (100) t.CustID, cm.currency, t.EventTypeID, t.AccumTurnover, t.AccumPayout, t.Matchid
			FROM #CustLimitBet_tmp t WITH(NOLOCK)
				INNER JOIN CUSTDB.dbo.Customer cm WITH (NOLOCK) ON t.CustID = cm.custid
				CROSS APPLY (SELECT	TOP 1 1 IsInvalid
							 FROM cte c
							 WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID AND c.matchid = t.Matchid
									AND ( c.Turnover_Accum <> t.AccumTurnover OR c.Payout_Accum <> t.AccumPayout)
									) AS tmp
			IF @@ROWCOUNT > 0
			BEGIN
				--retry one more time for sure
				WAITFOR DELAY '00:00:03.000'
				;WITH cte
				AS (
					SELECT b.custid,b.matchid,tmp.EventTypeID
						, SUM (PayoutAdjust) as Payout_Accum
						, SUM(TurnoverAdjust) as Turnover_Accum
					FROM bettrans b WITH (NOLOCK) 
						INNER JOIN #Result_Mismatch_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
						CROSS APPLY ( SELECT TOP 1 h.EventTypeID
												, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.PayoutAdjust) END AS PayoutAdjust
												, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.TurnoverAdjust) END AS TurnoverAdjust
										FROM CustLimitBetHistory_789 h WITH(NOLOCK)
										WHERE h.Transid = b.transid 
											AND h.EventTypeID = m.EventTypeID
										) AS tmp
					WHERE b.betfrom <> 'p'				
					GROUP BY b.custid,b.matchid,tmp.EventTypeID
				)
				INSERT INTO #Final (custid, Currency,eventtypeid, matchid)
				SELECT DISTINCT TOP (100) t.CustID, t.currency, t.EventTypeID, t.matchid
				FROM #Result_Mismatch_tmp t WITH(NOLOCK)
					INNER JOIN CustLimitBet_789 l WITH(NOLOCK) ON t.custid = l.CustID AND t.matchid = l.Matchid AND t.eventtypeid = l.EventTypeID
					CROSS APPLY (SELECT	TOP 1 1 IsInvalid
									FROM cte c
									WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID AND c.matchid = t.Matchid
										AND ( c.Turnover_Accum <> l.AccumTurnover OR c.Payout_Accum <> l.AccumPayout)
										) AS tmp

				SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',')  
				FROM
				(
					SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency <> 20
				) AS tmp

				
				SELECT @matchIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.matchid), ',')  
				FROM
				(
					SELECT DISTINCT t.matchid
					FROM #Final t
					WHERE t.currency <> 20
				) AS tmp

				IF ISNULL(@CustIDs,'') <> ''
					SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_789: Match/Outright/Betbuilder contains data mismatch with bettrans vs CustLimitBetHistory_789 tables for real currency. Top 100 custid(s): ' + @CustIDs + ', matchid(s): ' + @matchIDs + ', eventtypeid(s): '+ @EventtypeIDs + @CRLF
				----------------uus------------------------
				SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
				FROM
				(
					SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency = 20
				) AS tmp

				SELECT @UUSmatchIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.matchid), ',')  
				FROM
				(
					SELECT DISTINCT t.matchid
					FROM #Final t
					WHERE t.currency = 20
				) AS tmp

				IF ISNULL(@UUSCustIDs,'') <> ''
					SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_789: Match/Outright/Betbuilder contains data mismatch with bettrans vs CustLimitBetHistory_789 tables UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ', matchid(s): ' + @UUSmatchIDs + ', eventtypeid(s): '+ @EventtypeIDs + @CRLF
			END
		END
	END
	
	-------8. CustLimitBet_mbc: Eventtypeid 1,2,5 contains data mismatch with bettrans vs CustLimitBetHistory_mbc tables -------------------------
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,5'
		
		TRUNCATE TABLE #Result_Mismatch_tmp
		TRUNCATE TABLE #CustLimitBet_tmp
		TRUNCATE TABLE #Final

		INSERT INTO #CustLimitBet_tmp (matchid, custid, eventtypeid, accumTurnover, accumPayout)
		SELECT  t.Matchid,t.CustID, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_MBC t WITH(NOLOCK)
		WHERE t.EventTypeID IN (1,2,5) AND t.Matchid <> 29
			AND t.ModifiedDate BETWEEN @StartTime AND @EndTime
		
		IF @@ROWCOUNT > 0
		BEGIN
			;WITH cte
			AS (
				SELECT b.custid,b.matchid,tmp.EventTypeID
					, SUM (PayoutAdjust) as Payout_Accum
					, SUM(TurnoverAdjust) as Turnover_Accum
				FROM bettrans b WITH (NOLOCK) 
					INNER JOIN #CustLimitBet_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
					CROSS APPLY ( SELECT TOP 1 h.EventTypeID
											, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.PayoutAdjust)	END AS PayoutAdjust
											, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.TurnoverAdjust) END AS TurnoverAdjust
									FROM CustLimitBetHistory_MBC h WITH(NOLOCK)
									WHERE h.Transid = b.transid 
										AND h.EventTypeID = m.EventTypeID
									) AS tmp
				WHERE b.betfrom <> 'p'				
				GROUP BY b.custid,b.matchid,tmp.EventTypeID
			)

			INSERT INTO #Result_Mismatch_tmp (custid, Currency,eventtypeid, AccumTurnover, AccumPayout, matchid)
			SELECT TOP (100) t.CustID, cm.currency, t.EventTypeID, t.AccumTurnover, t.AccumPayout, t.Matchid
			FROM #CustLimitBet_tmp t WITH(NOLOCK)
				INNER JOIN CUSTDB.dbo.Customer cm WITH (NOLOCK) ON t.CustID = cm.custid
				CROSS APPLY (SELECT	TOP 1 1 IsInvalid
							 FROM cte c
							 WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID AND c.matchid = t.Matchid
									AND ( c.Turnover_Accum <> t.AccumTurnover OR c.Payout_Accum <> t.AccumPayout)
									) AS tmp
			IF @@ROWCOUNT > 0
			BEGIN
				--retry one more time for sure
				WAITFOR DELAY '00:00:03.000'
				;WITH cte
				AS (
					SELECT b.custid,b.matchid,tmp.EventTypeID
						, SUM (PayoutAdjust) as Payout_Accum
						, SUM(TurnoverAdjust) as Turnover_Accum
					FROM bettrans b WITH (NOLOCK) 
						INNER JOIN #Result_Mismatch_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
						CROSS APPLY ( SELECT TOP 1 h.EventTypeID
												, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.PayoutAdjust) END AS PayoutAdjust
												, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.TurnoverAdjust) END AS TurnoverAdjust
										FROM CustLimitBetHistory_MBC h WITH(NOLOCK)
										WHERE h.Transid = b.transid 
											AND h.EventTypeID = m.EventTypeID
										) AS tmp
					WHERE b.betfrom <> 'p'				
					GROUP BY b.custid,b.matchid,tmp.EventTypeID
				)
				INSERT INTO #Final (custid, Currency,eventtypeid, matchid)
				SELECT DISTINCT TOP (100) t.CustID, t.currency, t.EventTypeID, t.matchid
				FROM #Result_Mismatch_tmp t WITH(NOLOCK)
					INNER JOIN CustLimitBet_MBC l WITH(NOLOCK) ON t.custid = l.CustID AND t.matchid = l.Matchid AND t.eventtypeid = l.EventTypeID
					CROSS APPLY (SELECT	TOP 1 1 IsInvalid
									FROM cte c
									WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID AND c.matchid = t.Matchid
										AND ( c.Turnover_Accum <> l.AccumTurnover OR c.Payout_Accum <> l.AccumPayout)
										) AS tmp

				SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',')  
				FROM
				(
					SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency <> 20
				) AS tmp

				SELECT @matchIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.matchid), ',')  
				FROM
				(
					SELECT DISTINCT t.matchid
					FROM #Final t
					WHERE t.currency <> 20
				) AS tmp

				IF ISNULL(@CustIDs,'') <> ''
					SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_mbc: Match/Outright/Betbuilder contains data mismatch with bettrans vs CustLimitBetHistory_mbc tables for real currency. Top 100 custid(s): ' + @CustIDs + ', matchid(s): ' + @matchIDs + ', eventtypeid(s): '+ @EventtypeIDs + @CRLF
				----------------uus------------------------
				SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
				FROM
				(
					SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency = 20
				) AS tmp

				SELECT @UUSmatchIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.matchid), ',')  
				FROM
				(
					SELECT DISTINCT t.matchid
					FROM #Final t
					WHERE t.currency = 20
				) AS tmp

				IF ISNULL(@UUSCustIDs,'') <> ''
					SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_789: Match/Outright/Betbuilder contains data mismatch with bettrans vs CustLimitBetHistory_mbc tables UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ', matchid(s): ' + @UUSmatchIDs + 'eventtypeid(s): '+ @EventtypeIDs + @CRLF
			END
		END
	END

	-------8. CustLimitBet_LIC: Eventtypeid 1,2,5 contains data mismatch with bettrans vs CustLimitBetHistory_LIC tables -------------------------
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL
	BEGIN
		SELECT @CustIDs = '', @UUSCustIDs = '', @EventtypeIDs = '1,2,5'
		
		TRUNCATE TABLE #Result_Mismatch_tmp
		TRUNCATE TABLE #CustLimitBet_tmp
		TRUNCATE TABLE #Final

		INSERT INTO #CustLimitBet_tmp (matchid, custid, eventtypeid, accumTurnover, accumPayout)
		SELECT  t.Matchid,t.CustID, t.EventTypeID, t.AccumTurnover, t.AccumPayout
		FROM dbo.CustLimitBet_LIC t WITH(NOLOCK)
		WHERE t.EventTypeID IN (1,2,5) AND t.Matchid <> 29
			AND t.ModifiedDate BETWEEN @StartTime AND @EndTime
		
		IF @@ROWCOUNT > 0
		BEGIN
			;WITH cte
			AS (
				SELECT b.custid,b.matchid,tmp.EventTypeID
					, SUM (PayoutAdjust) as Payout_Accum
					, SUM(TurnoverAdjust) as Turnover_Accum
				FROM bettrans b WITH (NOLOCK) 
					INNER JOIN #CustLimitBet_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
					CROSS APPLY ( SELECT TOP 1 h.EventTypeID
											, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.PayoutAdjust)	END AS PayoutAdjust
											, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.TurnoverAdjust) END AS TurnoverAdjust
									FROM CustLimitBetHistory_LIC h WITH(NOLOCK)
									WHERE h.Transid = b.transid 
										AND h.EventTypeID = m.EventTypeID
									) AS tmp
				WHERE b.betfrom <> 'p'				
				GROUP BY b.custid,b.matchid,tmp.EventTypeID
			)

			INSERT INTO #Result_Mismatch_tmp (custid, Currency,eventtypeid, AccumTurnover, AccumPayout, matchid)
			SELECT TOP (100) t.CustID, cm.currency, t.EventTypeID, t.AccumTurnover, t.AccumPayout, t.Matchid
			FROM #CustLimitBet_tmp t WITH(NOLOCK)
				INNER JOIN CUSTDB.dbo.Customer cm WITH (NOLOCK) ON t.CustID = cm.custid
				CROSS APPLY (SELECT	TOP 1 1 IsInvalid
							 FROM cte c
							 WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID AND c.matchid = t.Matchid
									AND ( c.Turnover_Accum <> t.AccumTurnover OR c.Payout_Accum <> t.AccumPayout)
									) AS tmp
			IF @@ROWCOUNT > 0
			BEGIN
				--retry one more time for sure
				WAITFOR DELAY '00:00:03.000'
				;WITH cte
				AS (
					SELECT b.custid,b.matchid,tmp.EventTypeID
						, SUM (PayoutAdjust) as Payout_Accum
						, SUM(TurnoverAdjust) as Turnover_Accum
					FROM bettrans b WITH (NOLOCK) 
						INNER JOIN #Result_Mismatch_tmp m ON b.matchid = m.matchid AND b.custid = m.custid 
						CROSS APPLY ( SELECT TOP 1 h.EventTypeID
												, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.PayoutAdjust) END AS PayoutAdjust
												, CASE WHEN  b.statusid IN (102,101) THEN 0 ELSE ABS( h.TurnoverAdjust) END AS TurnoverAdjust
										FROM CustLimitBetHistory_LIC h WITH(NOLOCK)
										WHERE h.Transid = b.transid 
											AND h.EventTypeID = m.EventTypeID
										) AS tmp
					WHERE b.betfrom <> 'p'				
					GROUP BY b.custid,b.matchid,tmp.EventTypeID
				)
				INSERT INTO #Final (custid, Currency,eventtypeid,matchid)
				SELECT DISTINCT TOP (100) t.CustID, t.currency, t.EventTypeID,t.matchid
				FROM #Result_Mismatch_tmp t WITH(NOLOCK)
					INNER JOIN CustLimitBet_LIC l WITH(NOLOCK) ON t.custid = l.CustID AND t.matchid = l.Matchid AND t.eventtypeid = l.EventTypeID
					CROSS APPLY (SELECT	TOP 1 1 IsInvalid
									FROM cte c
									WHERE c.custid = t.CustID AND c.EventTypeID = t.EventTypeID AND c.matchid = t.Matchid
										AND ( c.Turnover_Accum <> l.AccumTurnover OR c.Payout_Accum <> l.AccumPayout)
										) AS tmp

				SELECT @CustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',')  
				FROM
				(
					SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency <> 20
				) AS tmp

				SELECT @matchIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.matchid), ',')  
				FROM
				(
					SELECT DISTINCT t.matchid
					FROM #Final t
					WHERE t.currency <> 20
				) AS tmp

				IF ISNULL(@CustIDs,'') <> ''
					SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_mbc: Match/Outright/Betbuilder contains data mismatch with bettrans vs CustLimitBetHistory_mbc tables for real currency. Top 100 custid(s): ' + @CustIDs + ', matchid(s): ' + @matchIDs + ', eventtypeid(s): '+ @EventtypeIDs + @CRLF
				----------------uus------------------------
				SELECT @UUSCustIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.custid), ',') 
				FROM
				(
					SELECT DISTINCT t.CustID
					FROM #Final t
					WHERE t.currency = 20
				) AS tmp

				SELECT @UUSmatchIDs = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.matchid), ',')  
				FROM
				(
					SELECT DISTINCT t.matchid
					FROM #Final t
					WHERE t.currency = 20
				) AS tmp

				IF ISNULL(@UUSCustIDs,'') <> ''
					SET @ErrorMessage = @ErrorMessage + '8. CustLimitBet_789: Match/Outright/Betbuilder contains data mismatch with bettrans vs CustLimitBetHistory_mbc tables UUS currency. Top 100 custid(s): ' + @UUSCustIDs + ', matchid(s): ' + @UUSmatchIDs + 'eventtypeid(s): '+ @EventtypeIDs + @CRLF
			END
		END
	END

	--SELECT CASE WHEN @ErrorMessage = '' THEN 'NO Error' ELSE @ErrorMessage END ErrorMessage, @StartTime StartTime, @EndTime EndTime

	DROP TABLE #TempReject
	DROP TABLE #RunningMatch
	DROP TABLE #NonSBRunningMatch
	DROP TABLE #Result_tmp
END
