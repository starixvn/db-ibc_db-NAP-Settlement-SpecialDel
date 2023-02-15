/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/   
/*	
	Created: 20230214@Max
    Task: Reset Turnover - [Redmine: #183838] - EvenTypeID = 4 (Mix Sports Parlay) - SiteDB

	DB: DBSIG/bodb02 
*/
USE [bodb02]
GO

DECLARE @CustIds VARCHAR(MAX) = ''
DECLARE @tmpCustId AS TABLE (CustId INT)
DECLARE @tmp_Bettrans AS TABLE(ID [int] IDENTITY (1,1) PRIMARY KEY, Custid INT, sum_stake MONEY, oddsid INT)
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
DECLARE @debug_message VARCHAR(500)

INSERT INTO @tmpCustId (CustId)
SELECT DISTINCT value 
FROM string_split (@CustIds, ',')

INSERT INTO @tmp_Bettrans (Custid, sum_stake, oddsid) --oddsid = 1: soccer, 99: mix sport
SELECT b.custid, ISNULL(SUM(b.stake),0) AS sum_stake, b.oddsid 
FROM bettrans b WITH (NOLOCK)	
	INNER JOIN @tmpCustId t ON t.CustId = b.CustID
WHERE matchid IN (9,29) 
	AND bettype IN (9,29) 
	AND ruben = 0
	AND b.oddsid = 99 --mix sport
GROUP BY b.custid, b.oddsid	

--Insert data for custid who doesn't have ticket on active range (stake = 0)
INSERT INTO @tmp_Bettrans (Custid, sum_stake, oddsid) 
SELECT t.CustId, 0 sum_stake, 99 oddsid -- Mix Sports Parlay
FROM @tmpCustId t 
WHERE NOT EXISTS (SELECT 1 FROM @tmp_Bettrans b WHERE t.CustId = b.Custid)

SET @MaxRow = (SELECT MAX(ID) FROM @tmp_Bettrans)
SET @Threshold = 1000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow
	
--LIC
--Mix sport; turnover = 0
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
	FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 99
	WHERE EventTypeID = 4
		AND matchid = 29 
		AND b.sum_stake = 0	
		AND l.AccumTurnover <>0
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

--Mix sport; turnover <> 0
-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
	PRINT @StartRow
	PRINT @StopRow

	UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = PO_History.sum_payout	
	FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)		
		INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 99
		CROSS APPLY (
				SELECT SUM(h.PayoutAdjust) AS sum_payout
				FROM CustLimitBetHistory_LIC h WITH (NOLOCK)
					INNER JOIN bettrans b WITH (NOLOCK) ON b.TransId = h.Transid AND b.statusID NOT IN (101)
				WHERE h.CustID = l.CustID
					AND h.Matchid = l.Matchid
					AND h.EventTypeID = l.EventTypeID
			) AS PO_History
	WHERE EventTypeID = 4
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
