/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Nap_Admin_CustLimitBet_CheckData_Job]
	@StartTime DATETIME OUTPUT,
	@EndTime DATETIME OUTPUT,
	@ErrorMessage VARCHAR(MAX) OUTPUT,
	@ErrMsg_Duplicate VARCHAR(MAX) OUTPUT
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
		- 20240327@Louisa: VS4 - Cock Fighting [Redmine:#199700]
		- 20240808@Max: Max Payout - Integrate Virtually Sports (VS5) [Redmine: #209070]
		- 20240923@Max: Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing [Redmine: #211145]
		- 20241031@Max: VS6 (Betby) - Company Max Payout & Max Payout Per Match [Redmine: #212547]
		- 20241203@Max: Improve performance of Max Payout per Match [Redmine: #214294]
		- 20250305@Max: Replace action reject by another actions for rule check duplicate [Redmine: #218599]
		- 20250328@Lani: [TVS] Upgrade ExchangeID data type [Redmine: #222191]

	Param's explanation:		
		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @SiteDBGroupID SMALLINT,
			@transIds VARCHAR(MAX),
			@UUSTransIds VARCHAR(MAX),
			@CRLF CHAR(2)

	SET @ErrorMessage = ''
	SET @ErrMsg_Duplicate = ''
	
	SET @StartTime   = DATEADD(MINUTE,-35,GETDATE())
	SET @EndTime   = DATEADD(MINUTE, -2,GETDATE())
	SET @CRLF = CHAR(13)+CHAR(10)

	SET @transIds = ''
	SET @UUSTransIds = ''

	CREATE TABLE #RunningMatch (matchid INT PRIMARY KEY, sporttype SMALLINT)
	CREATE TABLE #NonSBRunningMatch (matchid INT PRIMARY KEY)

	CREATE TABLE #Result_tmp (Transid BIGINT, matchid INT, custid INT, Currency SMALLINT)

	SET @SiteDBGroupID = (SELECT dbo.f_Get_SiteDBGroupID())

	INSERT INTO #RunningMatch(matchid, sporttype)
	SELECT m.matchid, m.sporttype
	FROM dbo.[match] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND (m.sporttype <= 99 OR m.sporttype IN (164,178,179,180,186,188,190,191,192,193,194,195,196,197))
	UNION ALL
	SELECT 29 matchid, NULL sporttype
	UNION ALL
	SELECT m.Match3rdId, m.sporttype
	FROM dbo.[Match3rd] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND m.sporttype IN (147,134)
	UNION ALL
	SELECT m.EventID, m.sporttype
	FROM dbo.VSRaceInfo m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND m.sporttype IN (177,198)

	INSERT INTO #NonSBRunningMatch(matchid)
	SELECT m.matchid
	FROM dbo.[match] m WITH (NOLOCK)
	WHERE m.eventstatus = 'running'
		AND m.sporttype > 99 AND m.sporttype NOT IN (164,178,179,180,186,188,190,191,192,193,194,195,196,197)

	----------------------------------------------------------Inserted data for excluded sporttype ---------------------------------------------------------
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,3)
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

	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,3)
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

	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,1,2)
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
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,3)
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
						AND b.bettype NOT IN (10,2799,10449,38,801,802,803,804,805,806) 
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
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,3)
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
						AND b.bettype NOT IN (10,2799,10449,38,801,802,803,804,805,806) 
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
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,1,2)
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
						AND b.bettype NOT IN (10,2799,10449,38,801,802,803,804,805,806) 
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
	IF OBJECT_ID('CustLimitBet_789', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,3)
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
	IF OBJECT_ID('CustLimitBet_MBC', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,3)
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
	IF OBJECT_ID('CustLimitBet_LIC', 'U') IS NOT NULL AND @SiteDBGroupID IN (0,1,2)
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

	-------------------------check duplicate data in queue table for void/recover/settle action --------------------------------------------------------------------

	--SELECT TOP 1 COUNT(1), q.ActionID, q.CustID, q.Matchid, q.EventTypeID, min(q.CreatedDate) MinDate , max (CreatedDate) MaxDate, q.Transids

	IF EXISTS (SELECT TOP 1 1
				FROM dbo.CustLimitBetQueue Q with (nolock)
				WHERE q.ActionID IN (1,3,4,5,6)
					AND q.CreatedDate BETWEEN @StartTime AND @EndTime
				GROUP BY q.ActionID, q.CustID, q.Matchid, q.Transids, q.EventTypeID
				HAVING count(1) > 1
				)
	BEGIN
		SELECT TOP 1 @ErrMsg_Duplicate = @ErrMsg_Duplicate +  '4. Duplicate data in Queue table. ' + @CRLF
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

	--SELECT CASE WHEN @ErrorMessage = '' THEN 'NO Error' ELSE @ErrorMessage END ErrorMessage, @StartTime StartTime, @EndTime EndTime

	DROP TABLE #TempReject
	DROP TABLE #RunningMatch
	DROP TABLE #NonSBRunningMatch
	DROP TABLE #Result_tmp
END
