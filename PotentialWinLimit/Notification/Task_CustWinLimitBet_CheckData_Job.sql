/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[Task_CustWinLimitBet_CheckData_Job]
	@ErrorMessage VARCHAR(MAX) OUTPUT
AS
/*	
	Created: 20250602@July
    Task: [Synergy] - Integration - Potential Winning Limit/Threshold - [Redmine: #226514]
    DB: DBSIC-bodb02
    Revisions:
		- 20250602@July: Create new SP - [Redmine: #226514]

	Param's explanation:		
*/
BEGIN

	SET NOCOUNT ON

	DECLARE @batch INT = 100,
			@transIds VARCHAR(MAX) = '' ,
			@UUSTransIds VARCHAR(MAX) = '',
			@CustIds VARCHAR(MAX) = '',
			@UUSCustIds VARCHAR(MAX) = '',
			@CRLF CHAR(2)

	SET @ErrorMessage = ''
	
	SET @CRLF = CHAR(13)+CHAR(10)

	CREATE TABLE #Result_tmp (
		  ID INT IDENTITY (1,1) PRIMARY KEY
		, Transid BIGINT
		, custid INT
		, Currency TINYINT
		, AccumToWin MONEY
		, AccumWinLoss MONEY
		, bettrans_AccumToWin MONEY
		, bettrans_AccumWinloss MONEY
		, diff_ToWin MONEY
		, diff_WinLoss MONEY
		, issueType SMALLINT
		, LatestResetDate DATETIME2(7)
	)
	CREATE TABLE #CustIdTransidList_tmp (transid BIGINT, custid INT, Currency TINYINT)
	CREATE TABLE #CustIdList_tmp (ID INT IDENTITY (1,1) PRIMARY KEY, custid INT, Currency TINYINT)
	CREATE TABLE #tmp_batch (custid INT PRIMARY KEY, Currency TINYINT, LatestResetDate DATETIME2(7), diff_ToWin MONEY, diff_WinLoss MONEY)

	CREATE TABLE #reset (ID INT IDENTITY (1,1) PRIMARY KEY, CustID INT, Currency TINYINT, LatestResetDate DATETIME2(7))
	DECLARE @tmp_RetryRule TABLE (custid INT, Currency TINYINT)

	DECLARE @LastTransId BIGINT
	      , @LastRepUpdateTime DATETIME2(7)
		  , @MaxTransId BIGINT
		  , @MaxRepUpdateTime DATETIME2(7)

	SELECT @LastTransId = CAST(VValue AS BIGINT)
	FROM dbo.systemsettings WITH (NOLOCK) WHERE VName = 'CustWinLimitBet_LastTransId'

	SELECT @LastRepUpdateTime = CAST(VValue AS DATETIME2(7))
	FROM dbo.systemsettings WITH (NOLOCK) WHERE VName = 'CustWinLimitBet_LastRepUpdateTime'
	
	SET @MaxRepUpdateTime = SYSDATETIME() 

	-----------------------------------------------------1 Check for missing data in CustWinLimitBet_History ---------------------------------------------------------
	BEGIN
		SELECT @MaxTransId = MAX(TransId) FROM dbo.bettrans WITH (NOLOCK)
		
		WAITFOR DELAY '00:00:03.000'

		INSERT INTO #Result_tmp (Transid, Currency, issueType)
		SELECT TOP (@batch) b.transid, b.currency, CASE WHEN c.Transid IS NULL THEN 1 ELSE 2 END AS issueType
		FROM dbo.bettrans b  WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON b.custid = v.custid
			CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
									WHERE m.bettype = b.bettype
									AND m.SportType < 99
									) AS chk
			LEFT JOIN dbo.CustWinLimitBet_History c WITH (NOLOCK) ON b.TransId = c.Transid AND b.custid = c.custid AND c.ActionType = 0
		WHERE  b.Transid > @lastTransid AND b.Transid <= @MaxTransId
		   AND b.bettype NOT IN (29,38) 
		   AND (c.Transid IS NULL
				OR (ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake <> c.AdjToWin)
				)
			AND v.site NOT IN ('Special','Hedging')

		INSERT INTO #Result_tmp (Transid, Currency, issueType)
		SELECT TOP (@batch) c.transid, v.currency, 3 AS issueType
		FROM dbo.CustWinLimitBet_History c WITH (NOLOCK) 
			INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON c.custid = v.custid
		WHERE c.ActionType = 0
			AND (c.bettype IN (29,38) OR c.Sporttype >=99)
			AND c.Transid > @lastTransid AND c.Transid <= @MaxTransId
		
		IF EXISTS (SELECT TOP 1 1 FROM #Result_tmp WHERE issueType = 1)
		BEGIN

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK) WHERE b.TransId = h.Transid AND b.custid = h.custid AND h.ActionType = 0)
					AND b.Currency <> 20 AND b.issueType = 1
			) AS tmp

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK) WHERE b.TransId = h.Transid AND b.custid = h.custid  AND h.ActionType = 0)
					AND b.Currency = 20 AND b.issueType = 1
			) AS tmp

			IF ISNULL(@transIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1.1. CustWinLimitBet_History table is missing data for real currency. Transid > '+ CAST (@lastTransid AS VARCHAR) + ' AND Transid <= '  + CAST (@MaxTransId AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @transIds + @CRLF
			END

			IF ISNULL(@UUStransIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1.1. CustWinLimitBet_History table is missing data for UUS currency. Transid > '+ CAST (@lastTransid AS VARCHAR) + ' AND Transid <= '  + CAST (@MaxTransId AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @UUStransIds + @CRLF
			END

		END
		
		IF EXISTS (SELECT TOP 1 1 FROM #Result_tmp WHERE issueType = 2)
		BEGIN
			SET @transIds = ''
			SET @UUStransIds = '' 

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency <> 20 AND b.issueType = 2
			) AS tmp

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency = 20 AND b.issueType = 2
			) AS tmp
			
			IF ISNULL(@transIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1.2. CustWinLimitBet_History table is different with table bettrans related to ToWin data for real currency. Transid > '+ CAST (@lastTransid AS VARCHAR) + ' AND Transid <= '  + CAST (@MaxTransId AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @transIds + @CRLF
			END

			IF ISNULL(@UUStransIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1.2. CustWinLimitBet_History table is different with table bettrans related to ToWin data for UUS currency. Transid > '+ CAST (@lastTransid AS VARCHAR) + ' AND Transid <= '  + CAST (@MaxTransId AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @UUStransIds + @CRLF
			END

		END

		IF EXISTS (SELECT TOP 1 1 FROM #Result_tmp WHERE issueType = 3)
		BEGIN
			SET @transIds = ''
			SET @UUStransIds = '' 
			
			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency <> 20 AND b.issueType = 3
			) AS tmp

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency = 20 AND b.issueType = 3
			) AS tmp
			
			IF ISNULL(@transIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1.3. CustWinLimitBet_History table have bettype IN (29,38) OR Sporttype >=99 for real currency. Transid > '+ CAST (@lastTransid AS VARCHAR) + ' AND Transid <= '  + CAST (@MaxTransId AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @transIds + @CRLF
			END

			IF ISNULL(@UUStransIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1.3. CustWinLimitBet_History table have bettype IN (29,38) OR Sporttype >=99 for UUS currency. Transid > '+ CAST (@lastTransid AS VARCHAR) + ' AND Transid <= '  + CAST (@MaxTransId AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @UUStransIds + @CRLF
			END

		END

		--Update value config
		UPDATE c SET c.VValue = @MaxTransId
		FROM dbo.systemsettings c WITH (ROWLOCK, UPDLOCK)
		WHERE c.VName = 'CustWinLimitBet_LastTransId'

	END
	
	-----------------------------------------------------2 Check special cases based on predefined conditions.--------------------------------------------------------------------
	BEGIN
		SET @transIds = ''
		SET @UUStransIds = '' 
		TRUNCATE TABLE #Result_tmp
		
		INSERT INTO #CustIdTransidList_tmp (transid, custid, Currency)
		SELECT DISTINCT c.transid, c.custid, v.currency
		FROM dbo.CustWinLimitBet_History c WITH (NOLOCK) 
			INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON c.custid = v.custid
		WHERE c.RepUpdateTime > @LastRepUpdateTime AND c.RepUpdateTime <= @MaxRepUpdateTime
			AND v.site NOT IN ('Special','Hedging')
			AND v.currency NOT IN (20)

		INSERT INTO #Result_tmp (Transid, Currency)
		SELECT TOP (@batch) l.transid, l.Currency
		FROM #CustIdTransidList_tmp l
			CROSS APPLY (SELECT Max(RepUpdateTime) as LatestResetDate
						 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK)
						 WHERE h.custid = l.custid and actiontype = 100
						 GROUP BY h.custid
						) AS rep
			CROSS APPLY (SELECT COUNT(1) AS cntTicket
						 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK)
						 WHERE h.transid = l.transid and h.RepUpdateTime > rep.LatestResetDate
						 GROUP BY h.custid
						 HAVING COUNT(1) >=3
						) AS cnt
			CROSS APPLY (SELECT TOP (1) 1 isCheck
						 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK)
						 WHERE h.transid = l.transid and repupdatetime > rep.LatestResetDate AND h.actiontype in (4,7)
						) AS t

		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
			) AS tmp
		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. After a reset, the ticket status may change continuously, which could lead to incorrect data if the SQL job processes all commands in a single batch. This rule applies only to real accounts. RepUpdateTime > '+ CAST (@LastRepUpdateTime AS VARCHAR) + ' AND RepUpdateTime <= '  + CAST (@MaxRepUpdateTime AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @transIds + @CRLF
		END
	END
	
	-----------------------------------------------------3 Check CustWinLimitBet.AccumToWin against Bettrans running tickets --------------------------------------------------------------------
	DECLARE @StartRow INT 
			, @StopRow INT 
			, @MaxRow INT  -- Keep the total row of your data
			, @Threshold INT  -- the number of each batch

	BEGIN
		SET @CustIds = ''
		SET @UUSCustIds = ''
		TRUNCATE TABLE #Result_tmp
		DELETE FROM @tmp_RetryRule
		
		INSERT INTO #CustIdList_tmp (custid, Currency)
		SELECT DISTINCT c.custid, v.currency
		FROM dbo.CustWinLimitBet_History c WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON c.custid = v.custid
		WHERE c.RepUpdateTime > @LastRepUpdateTime AND c.RepUpdateTime <= @MaxRepUpdateTime
			AND c.ActionType IN (0,4,7)
			AND v.site NOT IN ('Special','Hedging')

		SET @MaxRow = (SELECT MAX(ID) FROM #CustIdList_tmp)
		SET @Threshold = 300

		IF @Threshold >= @MaxRow
			SET @Threshold = @MaxRow

		-- SET for first batch
		SELECT @StartRow = 1, @StopRow = @Threshold

		WHILE (@MaxRow IS NOT NULL)
		BEGIN
			
			TRUNCATE TABLE #tmp_batch

			INSERT INTO #tmp_batch (custid, Currency)
			SELECT custid, currency
			FROM #CustIdList_tmp
			WHERE ID BETWEEN @StartRow AND @StopRow

			INSERT INTO #Result_tmp (CustId, Currency, AccumToWin, bettrans_AccumToWin, diff_ToWin)
			SELECT t.CustId, t.currency, c.AccumToWin, r.ToWin, r.ToWin - c.AccumToWin AS diff_ToWin
			FROM #tmp_batch t
				INNER JOIN dbo.CustWinLimitBet c WITH (NOLOCK) ON t.custid = c.custid
				CROSS APPLY (SELECT	 SUM(ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake) AS ToWin
							 FROM dbo.bettrans b  WITH (NOLOCK)
								CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
											WHERE m.bettype = b.bettype
											AND m.SportType < 99
											) AS chk
							 WHERE b.custid = t.CustID AND b.bettype NOT IN (29, 38)
									AND b.statusID IN (0,1) 
							 GROUP BY b.custid
							 ) AS r
			WHERE c.AccumToWin <> r.ToWin

			IF @StopRow = @MaxRow BREAK

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold
			IF @StopRow >= @MaxRow
				SET @StopRow = @MaxRow
		END

		IF EXISTS (SELECT TOP 1 1 FROM #Result_tmp)
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:03.000'
			
			SET @MaxRow = (SELECT MAX(ID) FROM #Result_tmp)
			SET @Threshold = 300

			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow

			-- SET for first batch
			SELECT @StartRow = 1, @StopRow = @Threshold

			WHILE (@MaxRow IS NOT NULL)
			BEGIN
			
				TRUNCATE TABLE #tmp_batch

				INSERT INTO #tmp_batch (custid, Currency, diff_ToWin)
				SELECT custid, Currency, diff_ToWin
				FROM #Result_tmp
				WHERE ID BETWEEN @StartRow AND @StopRow

				INSERT INTO @tmp_RetryRule (custid, Currency)
				SELECT t.custid, t.Currency
				FROM #tmp_batch t 
					INNER JOIN dbo.CustWinLimitBet c WITH (NOLOCK) ON t.custid = c.custid
					CROSS APPLY (SELECT	 SUM(ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake) AS ToWin
									FROM dbo.bettrans b  WITH (NOLOCK)
									CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
												WHERE m.bettype = b.bettype
												AND m.SportType < 99
												) AS chk
									WHERE b.custid = t.CustID AND b.bettype NOT IN (29, 38)
										AND b.statusID IN (0,1) 
									GROUP BY b.custid
									) AS r
				WHERE t.diff_ToWin = (r.ToWin - c.AccumToWin)
				
				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow
			END
			
			IF EXISTS (SELECT TOP 1 1 FROM @tmp_RetryRule)
			BEGIN
				SELECT @CustIds = STRING_AGG(CONVERT(VARCHAR(MAX),custid), ',') 
				FROM (
					SELECT TOP (@batch) custid
					FROM @tmp_RetryRule
					WHERE Currency <> 20
					)t

				SELECT @UUSCustIds = STRING_AGG(CONVERT(VARCHAR(MAX),custid), ',') 
				FROM (
					SELECT TOP (@batch) custid
					FROM @tmp_RetryRule
					WHERE Currency <> 20
					)t
			END
		END

		IF ISNULL(@CustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '3. Check CustWinLimitBet.AccumToWin against Bettrans running tickets for real currency. RepUpdateTime > '+ CAST (@LastRepUpdateTime AS VARCHAR) + ' AND RepUpdateTime <= '  + CAST (@MaxRepUpdateTime AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' CustId(s): ' + @CustIds + @CRLF
		END

		IF ISNULL(@UUSCustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '3. Check CustWinLimitBet.AccumToWin against Bettrans running tickets for UUS currency. RepUpdateTime > '+ CAST (@LastRepUpdateTime AS VARCHAR) + ' AND RepUpdateTime <= '  + CAST (@MaxRepUpdateTime AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' CustId(s): ' + @UUSCustIds + @CRLF
		END
	END
	
	-----------------------------------------------------4 For members with isDaily = Yes -----------------------------------------------------
	/*Schedule a daily job (at 4:00 AM server time) to compare CustWinLimitBet.AccumWinLoss against the sum of settled tickets in Bettrans since the latest reset.*/

	DECLARE @CurrentTime TIME = CONVERT(TIME, GETDATE());
	DECLARE @Today		DATETIME 
		   ,@Nextday    DATETIME

	IF @CurrentTime >= '03:59:00' AND @CurrentTime < '04:20:00' --Maximum call 2 times because job interval 10 minute
	BEGIN
		SET @Today = CAST(GETDATE() AS DATE)
		SET @Nextday = DATEADD(DAY, 1, @Today)

		SET @CustIds = ''
		SET @UUSCustIds = ''
		TRUNCATE TABLE #Result_tmp
		DELETE FROM @tmp_RetryRule

		INSERT INTO #reset (CustID, LatestResetDate, Currency)
		SELECT c.CustID, MAX(c.RepUpdateTime) AS LatestResetDate, v.currency
		FROM dbo.CustWinLimitBet_History c WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON c.custid = v.custid
		WHERE c.ActionType = 100 -- latest reset
			AND c.RepUpdateTime >= @Today and c.RepUpdateTime < @Nextday
			AND v.site NOT IN ('Special','Hedging')
		GROUP BY c.CustID, v.currency

		SET @MaxRow = (SELECT MAX(ID) FROM #reset)
		SET @Threshold = 300

		IF @Threshold >= @MaxRow
			SET @Threshold = @MaxRow

		-- SET for first batch
		SELECT @StartRow = 1, @StopRow = @Threshold

		WHILE (@MaxRow IS NOT NULL)
		BEGIN
			TRUNCATE TABLE #tmp_batch

			INSERT INTO #tmp_batch (custid, Currency, LatestResetDate)
			SELECT custid, Currency, LatestResetDate
			FROM #reset
			WHERE ID BETWEEN @StartRow AND @StopRow

			INSERT INTO #Result_tmp (custid, Currency, AccumToWin, AccumWinLoss, bettrans_AccumToWin, bettrans_AccumWinloss, diff_ToWin, diff_WinLoss, LatestResetDate)
			SELECT c.CustID, t.Currency, c.AccumToWin, c.AccumWinLoss, r.ToWin AS bettrans_AccumToWin, r.WinLoss AS bettrans_AccumWinloss
				, r.ToWin - c.AccumToWin AS diff_ToWin, r.WinLoss - c.AccumWinLoss AS diff_WinLoss, t.LatestResetDate
			FROM #tmp_batch t WITH (NOLOCK)
				INNER JOIN dbo.CustWinLimitBet c WITH (NOLOCK) ON t.CustID = c.custid
				CROSS APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
								   , SUM (CASE WHEN b.statusID NOT IN (0,1) AND (t2.LatestResetDate IS NULL OR settlementtime > t2.LatestResetDate) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
							 FROM dbo.bettrans b WITH (NOLOCK)
								CROSS APPLY (SELECT TOP (1) 1 AS isValid 
											 FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
											 WHERE m.bettype = b.bettype AND m.SportType < 99
											) AS chk
								OUTER APPLY (SELECT LatestResetDate
											FROM #tmp_batch c
											WHERE c.CustID = b.CustID
											) AS t2
							 WHERE b.custid = c.CustID AND b.bettype NOT IN (29, 38)
									AND b.statusID NOT IN (101,102,103,111)
							 GROUP BY b.custid
							 ) AS r
			WHERE (c.AccumToWin <> r.ToWin OR c.AccumWinLoss <> r.WinLoss)

			IF @StopRow = @MaxRow BREAK

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold
			IF @StopRow >= @MaxRow
				SET @StopRow = @MaxRow

		END 

		IF EXISTS (SELECT TOP 1 1 FROM #Result_tmp)
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:03.000'
			
			SET @MaxRow = (SELECT MAX(ID) FROM #Result_tmp)
			SET @Threshold = 300

			IF @Threshold >= @MaxRow
				SET @Threshold = @MaxRow

			-- SET for first batch
			SELECT @StartRow = 1, @StopRow = @Threshold

			WHILE (@MaxRow IS NOT NULL)
			BEGIN
			
				TRUNCATE TABLE #tmp_batch
				
				INSERT INTO #tmp_batch (custid, Currency, LatestResetDate, diff_ToWin, diff_WinLoss)
				SELECT custid, Currency, LatestResetDate, diff_ToWin, diff_WinLoss
				FROM #Result_tmp
				WHERE ID BETWEEN @StartRow AND @StopRow

				INSERT INTO @tmp_RetryRule (custid, Currency)
				SELECT TOP (@batch) t.custid, t.Currency
				FROM #tmp_batch t 
					INNER JOIN dbo.CustWinLimitBet c WITH (NOLOCK) ON t.CustID = c.custid
					CROSS APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
										, SUM (CASE WHEN b.statusID NOT IN (0,1) AND (t2.LatestResetDate IS NULL OR settlementtime > t2.LatestResetDate) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
									FROM dbo.bettrans b WITH (NOLOCK)
									CROSS APPLY (SELECT TOP (1) 1 AS isValid 
													FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
													WHERE m.bettype = b.bettype AND m.SportType < 99
												) AS chk
									OUTER APPLY (SELECT LatestResetDate
												FROM #tmp_batch c
												WHERE c.CustID = b.CustID
												) AS t2
									WHERE b.custid = c.CustID AND b.bettype NOT IN (29, 38)
										AND b.statusID NOT IN (101,102,103,111)
									GROUP BY b.custid
									) AS r
				WHERE (t.diff_ToWin = (r.ToWin - c.AccumToWin)) OR (t.diff_WinLoss = (r.WinLoss - c.AccumWinLoss))
			
				IF @StopRow = @MaxRow BREAK

				SET @StartRow = @StopRow + 1
				SET @StopRow = @StopRow + @Threshold
				IF @StopRow >= @MaxRow
					SET @StopRow = @MaxRow
			END

			IF EXISTS (SELECT TOP 1 1 FROM @tmp_RetryRule)
			BEGIN
				
				SELECT @CustIds = STRING_AGG(CONVERT(VARCHAR(MAX),custid), ',') 
				FROM (
					SELECT TOP (@batch) custid
					FROM @tmp_RetryRule
					WHERE Currency <> 20
					)t

				SELECT @UUSCustIds = STRING_AGG(CONVERT(VARCHAR(MAX),custid), ',') 
				FROM (
					SELECT TOP (@batch) custid
					FROM @tmp_RetryRule
					WHERE Currency <> 20
					)t
			END
		END

		IF ISNULL(@CustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '4. For members with isDaily = Yes. Check CustWinLimitBet.AccumToWin & AccumWinLoss against Bettrans running/ settle tickets for real currency. RepUpdateTime >= '+ CONVERT(VARCHAR,@Today,23) + ' AND RepUpdateTime < '  + CONVERT(VARCHAR,@Nextday,23) + '. Top ' + CAST (@batch AS VARCHAR) +  ' CustId(s): ' + @CustIds + @CRLF
		END

		IF ISNULL(@UUSCustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '4. For members with isDaily = Yes. Check CustWinLimitBet.AccumToWin & AccumWinLoss against Bettrans running/ settle tickets for UUS currency. RepUpdateTime >= '+ CONVERT(VARCHAR,@Today,23) + ' AND RepUpdateTime < '  + CONVERT(VARCHAR,@Nextday,23) + '. Top ' + CAST (@batch AS VARCHAR) +  ' CustId(s): ' + @UUSCustIds + @CRLF
		END
	END

	-----------------------------------------------------5 Sum data from CustWinLimitBet_History after the most recent reset, Compare with ticket data from Bettrans to ensure consistency -----------------------------------------------------
	BEGIN
		SET @CustIds = ''
		SET @UUSCustIds = ''
		
		TRUNCATE TABLE #Result_tmp
		TRUNCATE TABLE #reset
		TRUNCATE TABLE #CustIdTransidList_tmp

		INSERT INTO #CustIdTransidList_tmp (transid, custid, Currency)
		SELECT DISTINCT c.transid, c.custid, v.currency
		FROM dbo.CustWinLimitBet_History c WITH (NOLOCK)
				INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON c.custid = v.custid
		WHERE c.RepUpdateTime > @LastRepUpdateTime AND c.RepUpdateTime <= @MaxRepUpdateTime
			AND v.site NOT IN ('Special','Hedging')

		INSERT INTO #reset (CustID, LatestResetDate)
		SELECT c.CustID, MAX(c.RepUpdateTime) as LatestResetDate
		FROM dbo.CustWinLimitBet_History c WITH (NOLOCK)
			INNER JOIN #CustIdTransidList_tmp t ON c.CustID = t.custid
		WHERE c.ActionType = 100 -- latest reset
		GROUP BY c.CustID
		
		--- Remove custid does not perform any reset action.
		DELETE t
		FROM #CustIdTransidList_tmp t
		WHERE t.custid NOT IN (SELECT custid FROM #reset)
		
		--- Remove ticket placing bet before reset due to very difficult to check OR not exists table xxx_history then IGNORE
		DELETE t
		FROM #CustIdTransidList_tmp t
			LEFT JOIN dbo.CustWinLimitBet_History c WITH (NOLOCK) ON t.TransId = c.Transid AND t.custid = c.custid AND c.ActionType = 0 
			INNER JOIN #reset r ON r.CustID = t.custid
		WHERE c.Transid IS NULL OR c.RepUpdateTime < r.LatestResetDate
		
		--- Remove ticket in bettrans14
		DELETE t
		FROM #CustIdTransidList_tmp t
			LEFT JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.TransId 
		WHERE b.TransId IS NULL

		; WITH cte AS
		(
			SELECT DISTINCT custid, Currency FROM #CustIdTransidList_tmp
		)
		INSERT INTO #Result_tmp (custid, Currency, AccumToWin, AccumWinLoss, bettrans_AccumToWin, bettrans_AccumWinloss, diff_ToWin, diff_WinLoss)
		SELECT TOP (@batch) cl.CustID, cl.currency, lm.AccumToWin, lm.AccumWinLoss, r.ToWin AS bettrans_AccumToWin, r.WinLoss AS bettrans_AccumWinloss
					, r.ToWin - lm.AccumToWin AS diff_ToWin, r.WinLoss - lm.AccumWinLoss AS diff_WinLoss
		FROM cte  cl
			CROSS APPLY (SELECT SUM(AdjToWin) AS AccumToWin, SUM(AdjWinloss) AS AccumWinLoss
						FROM dbo.CustWinLimitBet_History h WITH (NOLOCK)
							INNER JOIN #CustIdTransidList_tmp r ON h.Transid = r.transid AND h.CustID = r.custid
						WHERE cl.CustID = h.custid
						GROUP BY h.CustID
						) AS lm
			CROSS APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
							   , SUM (CASE WHEN b.statusID NOT IN (0,1) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
							FROM dbo.bettrans b WITH (NOLOCK)
								INNER JOIN #CustIdTransidList_tmp r ON b.Transid = r.transid AND b.CustID = r.custid
							WHERE b.custid = cl.CustID
								AND b.bettype NOT IN (29, 38)
								AND b.statusID NOT IN (101,102,103,111)
							GROUP BY b.custid
							) AS r
		WHERE (lm.AccumToWin <> r.ToWin OR lm.AccumWinLoss <> r.WinLoss)
		ORDER BY CASE WHEN cl.Currency NOT IN (20) THEN 1
		              WHEN cl.Currency IN (20) THEN 2
					  ELSE 0 END ASC 

		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @CustIds = STRING_AGG(CONVERT(VARCHAR(MAX),custid), ',') 
			FROM #Result_tmp
			WHERE Currency <> 20

			SELECT @UUSCustIds = STRING_AGG(CONVERT(VARCHAR(MAX),custid), ',') 
			FROM #Result_tmp
			WHERE Currency = 20
		END

		IF ISNULL(@CustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '5. Sum data from CustWinLimitBet_History after the most recent reset, Compare with ticket data from Bettrans to ensure consistency for real currency. RepUpdateTime > '+ CAST (@LastRepUpdateTime AS VARCHAR) + ' AND RepUpdateTime <= '  + CAST (@MaxRepUpdateTime AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' CustId(s): ' + @CustIds + @CRLF
		END

		IF ISNULL(@UUSCustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '5. Sum data from CustWinLimitBet_History after the most recent reset, Compare with ticket data from Bettrans to ensure consistency for UUS currency. RepUpdateTime > '+ CAST (@LastRepUpdateTime AS VARCHAR) + ' AND RepUpdateTime <= '  + CAST (@MaxRepUpdateTime AS VARCHAR) + '. Top ' + CAST (@batch AS VARCHAR) +' CustId(s): ' + @UUSCustIds + @CRLF
		END
	END
		
	--Update value config
	UPDATE c SET c.VValue =  CONVERT(VARCHAR(50), @MaxRepUpdateTime, 21)
	FROM dbo.systemsettings c WITH (ROWLOCK, UPDLOCK)
	WHERE c.VName = 'CustWinLimitBet_LastRepUpdateTime'

	DROP TABLE #Result_tmp
	DROP TABLE #CustIdList_tmp
	DROP TABLE #reset
	DROP TABLE #CustIdTransidList_tmp
END

