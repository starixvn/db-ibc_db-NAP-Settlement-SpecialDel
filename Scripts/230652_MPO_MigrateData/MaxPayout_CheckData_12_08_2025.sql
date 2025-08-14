/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
--DB: DBSIC/bodb02
--------- Part 1: checking new transid (major bettype) with payout in history = 0
DECLARE @transid BIGINT = xxx
SELECT TOP 100 bt.transid, IIF(s.sitelabel = '789y', 2, 1) AS SiteType,
	ISNULL(
		CAST(
			CAST(bt.ExtraInfo AS XML).value('(/p1/@pa)[1]', 'VARCHAR(50)') AS MONEY
		), 
		0
	) AS PayoutAdjust
	, p_mbc.PayoutAdjust, p_789.PayoutAdjust
FROM bettrans bt with (nolock)
	INNER JOIN match m with (nolock) on m.matchid = bt.matchid 
	INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = bt.custid
	INNER JOIN CustDB.dbo.site s WITH (NOLOCK) ON s.site = c.site
	OUTER APPLY (SELECT TOP 1 m1.PayoutAdjust
					FROM dbo.CustLimitBetHistory_MBC m1 WITH (NOLOCK)
					WHERE m1.Matchid = bt.MatchId 
						AND m1.CustID = bt.CustID 
						AND m1.Transid = bt.TransId
						AND s.sitelabel <> '789y'
				) AS p_mbc
	OUTER APPLY (SELECT TOP 1 m1.PayoutAdjust
					FROM dbo.CustLimitBetHistory_789 m1 WITH (NOLOCK)
					WHERE m1.Matchid = bt.MatchId 
						AND m1.CustID = bt.CustID 
						AND m1.Transid = bt.TransId
						AND s.sitelabel = '789y'
				) AS p_789
WHERE bt.transid > @transid
	AND bt.bettype IN (1,3,5,7,8,15,20,21,153,501,609,610,612,701,704,705,9400,9404,9405,9406,9407,9408,9409,9522,9604,8800,8801,8802,8803,8804,8805,8806,8807,8808,8809,8810,8811,8812,8814,8815,8816,8817,8818,8819,8820,8821,8823,8824,8827,8828,8829,8830,8832,8833)
	AND m.eventstatus = 'running' and m.sporttype <= 99 AND m.sporttype NOT IN (43, 44)
	AND (p_mbc.PayoutAdjust = 0 OR p_789.PayoutAdjust = 0)
	AND bt.statusID IN (0,1)
---------------- Part 2: Check VOID ticket after update history table #UpdatedTransIds (STEP DATA migration) ----------------------------
SELECT TOP 100 b.transid, b.matchid,b.custid, b.transdate AS voidtime
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #UpdatedTransIds t ON b.transid = t.transid

SELECT DISTINCT b.matchid,b.custid
INTO #temp_Matchid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN #UpdatedTransIds t ON b.transid = t.transid

SELECT TOP 100 lm.*, r.Payout, r.Payout - lm.AccumPayout AS diff
FROM CustLimitBet_MBC lm WITH (NOLOCK)  
	INNER JOIN #temp_Matchid t ON lm.matchid = t.matchid
	INNER JOIN match m with (NOLOCK) ON m.matchid = t.matchid AND m.sporttype <= 99 AND m.eventstatus = 'running'
	CROSS APPLY (SELECT	 SUM(ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0)) AS Payout
				 FROM dbo.bettrans b with (nolock)
				 WHERE b.custid = lm.CustID
						AND b.matchid = lm.Matchid
						AND b.statusID NOT IN (101,102) -- reject, void: not counted
				  GROUP BY b.matchid, b.custid
				 ) AS r
WHERE lm.EventTypeID = 1 AND (lm.AccumPayout <> r.Payout)
	
---------------- Part 3: Check DIFF ----------------------------
CREATE TABLE #RunningMatch (matchid INT PRIMARY KEY, sporttype SMALLINT, eventdate DATETIME)
INSERT INTO #RunningMatch(matchid, sporttype, eventdate)
SELECT m.matchid, m.sporttype, eventdate
FROM dbo.[match] m WITH (NOLOCK)
	INNER JOIN League l WITH (NOLOCK) ON m.leagueid = l.leagueid AND l.isTest = 0
WHERE m.eventstatus = 'running'
	AND m.sporttype <= 99
	AND m.sporttype NOT IN (43, 44) --No need to process for Esports & MuayThai

CREATE TABLE #diff_MBC_1 (id INT IDENTITY (1,1),_site VARCHAR(20), matchid INT, sporttype smallint, eventdate datetime, custid INT, accumPayout MONEY, bettrans_Payout MONEY, diff MONEY)
CREATE TABLE #diff_789_1 (id INT IDENTITY (1,1),_site VARCHAR(20), matchid INT, sporttype smallint, eventdate datetime, custid INT, accumPayout MONEY, bettrans_Payout MONEY, diff MONEY)

INSERT INTO #diff_MBC_1 (_site, matchid, sporttype, eventdate, custid, accumPayout, bettrans_Payout, diff)
SELECT 'MBC' _site,t.matchid,t.sporttype,t.eventdate, lm.CustID, lm.AccumPayout, r.Payout as bettrans_Payout, r.Payout - lm.AccumPayout  AS diff
FROM #RunningMatch t 
	INNER JOIN CustLimitBet_MBC lm WITH (NOLOCK) ON t.matchid = lm.Matchid AND lm.EventTypeID = 1
	CROSS APPLY (SELECT	 SUM(ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0)) AS Payout
				 FROM dbo.bettrans b with (nolock)
				 WHERE b.custid = lm.CustID
						AND b.matchid = lm.Matchid
						AND b.statusID NOT IN (101,102) -- reject, void: not counted
				  GROUP BY b.matchid, b.custid
				 ) AS r
WHERE (lm.AccumPayout <> r.Payout)

INSERT INTO #diff_789_1 (_site, matchid, sporttype, eventdate, custid, accumPayout, bettrans_Payout, diff)
SELECT '789y' _site,t.matchid,t.sporttype,t.eventdate, lm.CustID, lm.AccumPayout, r.Payout as bettrans_Payout, r.Payout - lm.AccumPayout  AS diff
FROM #RunningMatch t 
	INNER JOIN CustLimitBet_789 lm WITH (NOLOCK) ON t.matchid = lm.Matchid AND lm.EventTypeID = 1
	CROSS APPLY (SELECT	 SUM(ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0)) AS Payout
				 FROM dbo.bettrans b WITH (NOLOCK)
				 WHERE b.custid = lm.CustID
						AND b.matchid = lm.Matchid
						AND b.statusID NOT IN (101,102) -- reject, void: not counted
				 GROUP BY b.matchid, b.custid
				 ) AS r
WHERE (lm.AccumPayout <> r.Payout)

----------Part 3: Correct Data -------------------
/*
------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch

DECLARE @debug_message VARCHAR(500)
IF EXISTS (SELECT TOP 1 1 FROM #diff_MBC_1)
BEGIN
	SET @MaxRow = (SELECT MAX(ID) FROM #diff_MBC_1)
	SET @Threshold = 1000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold

	WHILE (@MaxRow IS NOT NULL)
	BEGIN
			PRINT @StartRow
			PRINT @StopRow
			
			UPDATE TOP (100) s_mbc
				SET AccumPayout = s_mbc.AccumPayout + t.diff
			FROM CustLimitBet_MBC s_mbc WITH (ROWLOCK,UPDLOCK)
				INNER JOIN #diff_MBC_1 t ON s_mbc.Matchid = t.matchid AND s_mbc.EventTypeID = 1 AND t.CustID = s_mbc.CustID
			WHERE t.ID BETWEEN @StartRow AND @StopRow

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
			RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
			IF @StopRow = @MaxRow BREAK

			WAITFOR DELAY '00:00:00.100' --optional

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold
			IF @StopRow >= @MaxRow
				SET @StopRow = @MaxRow

	END

END

IF EXISTS (SELECT TOP 1 1 FROM #diff_789_1)
BEGIN
	SET @MaxRow = (SELECT MAX(ID) FROM #diff_789_1)
	SET @Threshold = 1000

	IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

	-- SET for first batch
	SELECT @StartRow = 1, @StopRow = @Threshold

	WHILE (@MaxRow IS NOT NULL)
	BEGIN
			PRINT @StartRow
			PRINT @StopRow
			
			-- YOUR CODE TO PROCESS DATA FROM @StartRow & @StopRow
			UPDATE TOP (100) s_789
				SET AccumPayout = s_789.AccumPayout + t.diff
			FROM CustLimitBet_789 s_789 WITH (ROWLOCK,UPDLOCK)
				INNER JOIN #diff_789_1 t ON s_789.Matchid = t.matchid AND s_789.EventTypeID = 1 AND t.CustID = s_789.CustID
			WHERE t.ID BETWEEN @StartRow AND @StopRow

			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
			RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
			IF @StopRow = @MaxRow BREAK

			WAITFOR DELAY '00:00:00.100' --optional

			SET @StartRow = @StopRow + 1
			SET @StopRow = @StopRow + @Threshold
			IF @StopRow >= @MaxRow
				SET @StopRow = @MaxRow

	END

END
*/


 











