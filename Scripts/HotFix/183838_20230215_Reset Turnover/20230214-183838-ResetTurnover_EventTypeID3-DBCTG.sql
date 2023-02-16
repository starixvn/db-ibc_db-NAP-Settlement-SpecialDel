/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/   
/*	
	Created: 20230214@Max
    Task: Reset Turnover - [Redmine: #183838] - EvenTypeID = 3

	DB: DBCTG/bodb02 
*/
USE [bodb02]
GO
DECLARE @CustIds VARCHAR(MAX) = '1893827,16752767,20421017,21195858,27148294,27568044,28174467,28717562,30118247,31003756,41157080,43418853,44307051,44423859,44726387,44732258,44801893,45571844,50410036,54906428,60041055,61893418,63463132,64620442,67958610,26250963,29067539,42910057,46869465,47417328,47710847,49411230,52918009,53429735,53770602,55356874,56659016,57169652,57890063,59041054,59226764,63727773,63890400,64496379,65624475,67112365,67152120,67193439,67269739,67707562,68211397,68248082,68339938,68509472,15233278,7666188,54023651,8548825,12517603,52753392,27507920,12277917,16546411,35844802,19786485,46087064,1475672,29128829,9339850,19244461,24620168,25115029,10391941,23068229,3063668,19012017,55356874,50410036,20421017,57890063,28174467,49411230,27148294,57169652,67958610,68248082,67193439,67112365,68339938,59226764,47417328,68509472,64496379,56659016,67152120,26250963,65624475,63890400,42910057,53429735,29067539,53770602,60041055,46869465,59041054,67269739,52918009,19786485,44726387,10391941,41157080,21195858,46087064,68211397,19012017,24620168,27568044,31003756,44423859,54906428,19244461,47710847,35844802,15233278,64620442,45571844,25115029,27507920,54023651,43418853,12277917,28717562,8548825,29128829,63727773,12517603,9339850,44732258,16752767,44801893,23068229,61893418,3063668,1475672,1893827,16546411,63463132,7666188,44307051,67707562,30118247,52753392'
CREATE TABLE #tmpCustId (CustId INT)
CREATE TABLE #tmp_Bettrans (ID [int] IDENTITY (1,1) PRIMARY KEY, Custid INT, sum_stake MONEY, oddsid INT)
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
DECLARE @debug_message VARCHAR(500)

INSERT INTO #tmpCustId (CustId)
SELECT DISTINCT value 
FROM string_split (@CustIds, ',')

--Sum stake on active range
INSERT INTO #tmp_Bettrans (Custid, sum_stake, oddsid) --oddsid = 1: soccer, 99: mix sport
SELECT b.custid, ISNULL(SUM(b.stake),0) AS sum_stake, b.oddsid 
FROM bettrans b WITH (NOLOCK)	
	INNER JOIN #tmpCustId t ON t.CustId = b.CustID
WHERE matchid IN (9,29) 
	AND bettype IN (9,29) 
	AND ruben = 0
	AND b.oddsid = 1 -- Soccer Parlay
GROUP BY b.custid, b.oddsid

--Insert data for custid who doesn't have ticket on active range (stake = 0)
INSERT INTO #tmp_Bettrans (Custid, sum_stake, oddsid) 
SELECT t.CustId, 0 sum_stake, 1 oddsid --Soccer Parlay
FROM #tmpCustId t 
WHERE NOT EXISTS (SELECT 1 FROM #tmp_Bettrans b WHERE t.CustId = b.Custid)

SET @MaxRow = (SELECT MAX(ID) FROM #tmp_Bettrans)
SET @Threshold = 20000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

--MBC
--Soccer; turnover = 0
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
SET @MaxRow = (SELECT MAX(ID) FROM #tmp_Bettrans WHERE sum_stake = 0)

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
	FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN #tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
	WHERE EventTypeID = 3 
		AND matchid = 29 
		AND b.sum_stake = 0
		AND l.AccumTurnover <> 0
		AND b.ID BETWEEN @StartRow AND @StopRow

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.100' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
	SET @StopRow = @MaxRow
END

--Soccer; turnover <> 0
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
SET @MaxRow = (SELECT MAX(ID) FROM #tmp_Bettrans WHERE sum_stake <> 0)

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = ISNULL(PO_History.sum_payout,0)
	FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN #tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
		CROSS APPLY (
				SELECT SUM(h.PayoutAdjust) AS sum_payout
				FROM CustLimitBetHistory_MBC h WITH (NOLOCK)
					INNER JOIN bettrans b WITH (NOLOCK) ON b.TransId = h.Transid AND b.statusID NOT IN (101)
				WHERE h.CustID = l.CustID
					AND h.Matchid = l.Matchid
					AND h.EventTypeID = l.EventTypeID
			) AS PO_History
	WHERE EventTypeID = 3 
		AND matchid = 29 
		AND b.sum_stake <> 0
		AND b.sum_stake <> l.AccumTurnover
		AND b.ID BETWEEN @StartRow AND @StopRow

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.100' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
	SET @StopRow = @MaxRow
END

--789y
--Soccer; turnover = 0
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
SET @MaxRow = (SELECT MAX(ID) FROM #tmp_Bettrans WHERE sum_stake = 0)

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
	FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN #tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
	WHERE EventTypeID = 3 
		AND matchid = 29 
		AND b.sum_stake = 0
		AND l.AccumTurnover <> 0
		AND b.ID BETWEEN @StartRow AND @StopRow

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.100' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
	SET @StopRow = @MaxRow
END

--Soccer; turnover <> 0
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
SET @MaxRow = (SELECT MAX(ID) FROM #tmp_Bettrans WHERE sum_stake <> 0)

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = ISNULL(PO_History.sum_payout,0)
	FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN #tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
		CROSS APPLY (
				SELECT SUM(h.PayoutAdjust) AS sum_payout
				FROM CustLimitBetHistory_789 h WITH (NOLOCK)
					INNER JOIN bettrans b WITH (NOLOCK) ON b.TransId = h.Transid AND b.statusID NOT IN (101)
				WHERE h.CustID = l.CustID
					AND h.Matchid = l.Matchid
					AND h.EventTypeID = l.EventTypeID
			) AS PO_History
	WHERE EventTypeID = 3 
		AND matchid = 29 
		AND b.sum_stake <> 0
		AND b.sum_stake <> l.AccumTurnover
		AND b.ID BETWEEN @StartRow AND @StopRow

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.100' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
	SET @StopRow = @MaxRow
END
					
--LIC
--Soccer; turnover = 0
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
SET @MaxRow = (SELECT MAX(ID) FROM #tmp_Bettrans WHERE sum_stake = 0)

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
	FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN #tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
	WHERE EventTypeID = 3 
		AND matchid = 29 
		AND b.sum_stake = 0
		AND l.AccumTurnover <> 0
		AND b.ID BETWEEN @StartRow AND @StopRow

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.100' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
	SET @StopRow = @MaxRow
END


--Soccer; turnover <> 0

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
SET @MaxRow = (SELECT MAX(ID) FROM #tmp_Bettrans WHERE sum_stake <> 0)

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = ISNULL(PO_History.sum_payout,0)
	FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN #tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
		CROSS APPLY (
				SELECT SUM(h.PayoutAdjust) AS sum_payout
				FROM CustLimitBetHistory_LIC h WITH (NOLOCK)
					INNER JOIN bettrans b WITH (NOLOCK) ON b.TransId = h.Transid AND b.statusID NOT IN (101)
				WHERE h.CustID = l.CustID
					AND h.Matchid = l.Matchid
					AND h.EventTypeID = l.EventTypeID
			) AS PO_History
	WHERE EventTypeID = 3 
		AND matchid = 29 
		AND b.sum_stake <> 0
		AND b.sum_stake <> l.AccumTurnover
			AND b.ID BETWEEN @StartRow AND @StopRow

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

	IF @StopRow = @MaxRow BREAK

	WAITFOR DELAY '00:00:00.100' --optional

	SET @StartRow = @StopRow + 1
	SET @StopRow = @StopRow + @Threshold
	IF @StopRow >= @MaxRow
	SET @StopRow = @MaxRow
END

DROP TABLE #tmp_Bettrans
DROP TABLE #tmpCustId