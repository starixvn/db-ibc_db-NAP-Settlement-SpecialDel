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
		Note: Only sitedb3
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
	  Transid BIGINT
	, custid INT
	, Currency SMALLINT
	, AccumToWin MONEY
	, AccumWinLoss MONEY
	, bettrans_AccumToWin MONEY
	, bettrans_AccumWinloss MONEY
	, diff_ToWin MONEY
	, diff_WinLoss MONEY
	, issueType SMALLINT
	)

	DECLARE @LastTransId BIGINT
	      , @LastRepUpdateTime DATETIME2(7)

	SELECT @LastTransId = CAST(VValue AS BIGINT)
	FROM dbo.systemsettings WITH (NOLOCK) WHERE VName = 'CustWinLimitBet_LastTransId'

	SELECT @LastRepUpdateTime = CAST(VValue AS DATETIME2(7))
	FROM dbo.systemsettings WITH (NOLOCK) WHERE VName = 'CustWinLimitBet_LastRepUpdateTime'

	----------------------------------------------------------1 Check for missing data in CustWinLimitBet_History ---------------------------------------------------------
	BEGIN
		INSERT INTO #Result_tmp (Transid, Currency, issueType)
		SELECT TOP (@batch) b.transid, b.currency, CASE WHEN c.Transid IS NULL THEN 1 ELSE 0 END AS issueType
		FROM dbo.bettrans b  WITH (NOLOCK)
			CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
									WHERE m.bettype = b.bettype
									AND m.SportType < 99
									) AS chk
			LEFT JOIN dbo.CustWinLimitBet_History c WITH (NOLOCK) ON b.TransId = c.Transid AND c.ActionType = 0
		WHERE  b.Transid >= @lastTransid 
		   AND b.bettype NOT IN (29,38) 
		   AND (c.Transid IS NULL
				OR (ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake <> c.AdjToWin)
				)
		
		SET @LastTransId = (SELECT MAX(transid) FROM #Result_tmp)
		
		--Update value config
		UPDATE c SET c.VValue = @LastTransId
		FROM dbo.systemsettings c WITH (ROWLOCK, UPDLOCK)
		WHERE c.VName = 'CustWinLimitBet_LastTransId'

		IF EXISTS (SELECT TOP 1 1 FROM #Result_tmp WHERE issueType = 1)
		BEGIN
			--retry one more time for sure
			WAITFOR DELAY '00:00:02.000'

			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK) WHERE b.TransId = h.Transid AND h.ActionType = 0)
					AND b.Currency <> 20 AND b.issueType = 1
			) AS tmp

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.CustWinLimitBet_History h WITH (NOLOCK) WHERE b.TransId = h.Transid AND h.ActionType = 0)
					AND b.Currency = 20 AND b.issueType = 1
			) AS tmp

		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '1. CustWinLimitBet_History table is missing data for real currency. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @transIds + @CRLF
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '1. CustWinLimitBet_History table is missing data for UUS currency. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @UUStransIds + @CRLF
		END

		SET @transIds = ''
		SET @UUStransIds = '' 

		IF EXISTS (SELECT TOP 1 1 FROM #Result_tmp WHERE issueType = 0)
		BEGIN
			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency <> 20 AND b.issueType = 0
			) AS tmp

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency = 20 AND b.issueType = 0
			) AS tmp
			
			IF ISNULL(@transIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1. CustWinLimitBet_History table is different with table bettrans related to ToWin data for real currency. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @transIds + @CRLF
			END

			IF ISNULL(@UUStransIds,'') <> ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + '1. CustWinLimitBet_History table is different with table bettrans related to ToWin data for UUS currency. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @UUStransIds + @CRLF
			END

		END
	END
	
	DECLARE @tmp_MaxRepUpdateTime TABLE (RuleId INT, RepUpdateTime DATETIME2(7))
	-----------------------------------------------------2 Check special cases based on predefined conditions.--------------------------------------------------------------------
	BEGIN
		SET @transIds = ''
		SET @UUStransIds = ''
		TRUNCATE TABLE #Result_tmp
		
		CREATE TABLE #transidList (transid BIGINT, custid INT, RepUpdateTime DATETIME2(7))

		INSERT INTO #transidList (transid, custid, RepUpdateTime)
		SELECT DISTINCT transid, custid, RepUpdateTime
		FROM dbo.CustWinLimitBet_History WITH (NOLOCK) 
		WHERE RepUpdateTime > @LastRepUpdateTime
		
		INSERT INTO @tmp_MaxRepUpdateTime (RuleId, RepUpdateTime) 
		SELECT 2, MAX(RepUpdateTime)
		FROM #transidList

		INSERT INTO #Result_tmp (Transid, Currency)
		SELECT TOP (@batch) l.transid, v.Currency
		FROM #transidList l
			INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON l.custid = v.custid
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
		ORDER BY CASE WHEN v.Currency NOT IN (20) THEN 1
		              WHEN v.Currency IN (20) THEN 2
					  ELSE 0 END ASC 

		IF @@ROWCOUNT > 0
		BEGIN
			SELECT @transIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency <> 20
			) AS tmp

			SELECT @UUStransIds = STRING_AGG(CONVERT(VARCHAR(MAX),tmp.transId), ',') 
			FROM(
				SELECT DISTINCT b.transId
				FROM #Result_tmp b 
				WHERE b.Currency = 20
			) AS tmp
		END

		IF ISNULL(@transIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustWinLimitBet_History table is checking special cases based on predefined conditions for real currency. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @transIds + @CRLF
		END

		IF ISNULL(@UUStransIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '2. CustWinLimitBet_History table is checking special cases based on predefined conditions for UUS currency. Top ' + CAST (@batch AS VARCHAR) +' transId(s): ' + @UUStransIds + @CRLF
		END

	END
	
	-----------------------------------------------------3 Check CustWinLimitBet.AccumToWin against Bettrans running tickets --------------------------------------------------------------------
	CREATE TABLE #CustList (custid INT PRIMARY KEY, RepUpdateTime DATETIME2(7))
	
	BEGIN
		SET @CustIds = ''
		SET @UUSCustIds = ''
		TRUNCATE TABLE #Result_tmp

		INSERT INTO #CustList (custid, RepUpdateTime)
		SELECT DISTINCT custid, RepUpdateTime
		FROM dbo.CustWinLimitBet_History WITH (NOLOCK)
		WHERE RepUpdateTime > @LastRepUpdateTime AND actiontype in (0,4,7)

		INSERT INTO @tmp_MaxRepUpdateTime (RuleId, RepUpdateTime) 
		SELECT 3, MAX(RepUpdateTime)
		FROM #CustList

		INSERT INTO #Result_tmp (CustId, Currency)
		SELECT TOP (@batch) t.CustId, v.Currency
		FROM #CustList t
			INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON t.custid = v.custid
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
		ORDER BY CASE WHEN v.Currency NOT IN (20) THEN 1
		              WHEN v.Currency IN (20) THEN 2
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
			SET @ErrorMessage = @ErrorMessage + '3. Check CustWinLimitBet.AccumToWin against Bettrans running tickets for real currency. Top ' + CAST (@batch AS VARCHAR) +' CustId(s): ' + @CustIds + @CRLF
		END

		IF ISNULL(@UUSCustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '3. Check CustWinLimitBet.AccumToWin against Bettrans running tickets for UUS currency. Top ' + CAST (@batch AS VARCHAR) +' CustId(s): ' + @UUSCustIds + @CRLF
		END
	END
	
	SET @LastRepUpdateTime = (SELECT MIN(RepUpdateTime) FROM @tmp_MaxRepUpdateTime)
		
	--Update value config
	UPDATE c SET c.VValue =  CONVERT(VARCHAR(50), @LastRepUpdateTime, 21)
	FROM dbo.systemsettings c WITH (ROWLOCK, UPDLOCK)
	WHERE c.VName = 'CustWinLimitBet_LastRepUpdateTime'

	-----------------------------------------------------For members with isDaily = Yes -----------------------------------------------------
	/*Schedule a daily job (at 4:00 AM server time) to compare CustWinLimitBet.AccumWinLoss against the sum of settled tickets in Bettrans since the latest reset.*/

	DECLARE @CurrentTime TIME = CONVERT(TIME, GETDATE());
	DECLARE @Today		DATETIME 
		   ,@Nextday    DATETIME

	CREATE TABLE #reset (CustID INT, LatestResetDate DATETIME)

	IF @CurrentTime >= '03:59:00' AND @CurrentTime < '04:20:00' --Maximum call 2 times
	BEGIN
		SET @Today = CAST(GETDATE() AS DATE)
		SET @Nextday = DATEADD(DAY, 1, @Today)

		SET @CustIds = ''
		SET @UUSCustIds = ''
		TRUNCATE TABLE #Result_tmp
		
		INSERT INTO #reset (CustID, LatestResetDate)
		SELECT c.CustID, MAX(RepUpdateTime) as LatestResetDate
		FROM dbo.CustWinLimitBet_History c WITH (NOLOCK)
		WHERE c.ActionType = 100 -- latest reset
			AND c.RepUpdateTime >= @Today and c.RepUpdateTime < @Nextday
		GROUP BY c.CustID

		INSERT INTO #Result_tmp (custid, Currency, AccumToWin, AccumWinLoss, bettrans_AccumToWin, bettrans_AccumWinloss, diff_ToWin, diff_WinLoss)
		SELECT TOP (@batch) c.CustID, v.Currency, c.AccumToWin, c.AccumWinLoss, r.ToWin AS bettrans_AccumToWin, r.WinLoss as bettrans_AccumWinloss
			, r.ToWin - c.AccumToWin AS diff_ToWin, r.WinLoss - c.AccumWinLoss AS diff_WinLoss
		FROM #reset t WITH (NOLOCK)
			INNER JOIN CustDB.dbo.Customer v WITH (NOLOCK) ON t.custid = v.custid
			INNER JOIN dbo.CustWinLimitBet c WITH (NOLOCK) ON t.CustID = c.custid
			CROSS APPLY (SELECT	 SUM(CASE WHEN b.statusID IN (0,1) THEN ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake ELSE 0 END) AS ToWin
							   , SUM (CASE WHEN b.statusID NOT IN (0,1) AND (t2.LatestResetDate IS NULL OR settlementtime > t2.LatestResetDate) THEN b.winlost - b.actual_stake ELSE 0 END) AS WinLoss
						 FROM dbo.bettrans b WITH (NOLOCK)
							CROSS APPLY (SELECT TOP (1) 1 AS isValid 
										 FROM dbo.SportBettypeMatrix m WITH (NOLOCK)
										 WHERE m.bettype = b.bettype AND m.SportType < 99
										) AS chk
							OUTER APPLY (SELECT LatestResetDate
										FROM #reset c
										WHERE c.CustID = b.CustID
										) AS t2
						 WHERE b.custid = c.CustID AND b.bettype NOT IN (29, 38)
								AND b.statusID NOT IN (101,102,103,111)
						 GROUP BY b.custid
						 ) AS r
		WHERE (c.AccumToWin <> r.ToWin OR c.AccumWinLoss <> r.WinLoss)
		ORDER BY CASE WHEN v.Currency NOT IN (20) THEN 1
		              WHEN v.Currency IN (20) THEN 2
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
			SET @ErrorMessage = @ErrorMessage + '4. For members with isDaily = Yes. Check CustWinLimitBet.AccumToWin & AccumWinLoss against Bettrans running/ settle tickets for real currency. Top ' + CAST (@batch AS VARCHAR) +  ' CustId(s): ' + @CustIds + @CRLF
		END

		IF ISNULL(@UUSCustIds,'') <> ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + '4. For members with isDaily = Yes. Check CustWinLimitBet.AccumToWin & AccumWinLoss against Bettrans running/ settle tickets for UUS currency. Top ' + CAST (@batch AS VARCHAR) +  ' CustId(s): ' + @UUSCustIds + @CRLF
		END
	END

	DROP TABLE #Result_tmp
	DROP TABLE #CustList
	DROP TABLE #reset
	DROP TABLE #transidList
END
