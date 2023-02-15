/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/   
/*	
	Created: 20230214@Max
    Task: Reset Turnover - [Redmine: #183838] - EvenTypeID = 3

	DB: DBCTG/bodb02 
*/
USE [bodb02]
GO
DECLARE @CustIds VARCHAR(MAX) = ''
DECLARE @tmpCustId AS TABLE (CustId INT)
DECLARE @tmp_Bettrans AS TABLE(Custid INT, sum_stake MONEY, oddsid INT)
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch

INSERT INTO @tmpCustId (CustId)
SELECT DISTINCT value 
FROM string_split (@CustIds, ',')

--Sum stake on active range
INSERT INTO @tmp_Bettrans (Custid, sum_stake, oddsid) --oddsid = 1: soccer, 99: mix sport
SELECT b.custid, ISNULL(SUM(b.stake),0) AS sum_stake, b.oddsid 
FROM bettrans b WITH (NOLOCK)	
	INNER JOIN @tmpCustId t ON t.CustId = b.CustID
WHERE matchid IN (9,29) 
	AND bettype IN (9,29) 
	AND ruben = 0
GROUP BY b.custid, b.oddsid

SET @MaxRow = (SELECT MAX(ID) FROM @tmp_Bettrans)
SET @Threshold = 20000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

--Insert data for custid who doesn't have ticket on active range (stake = 0)
INSERT INTO @tmp_Bettrans (Custid, sum_stake, oddsid) 
SELECT t.CustId, 0 sum_stake, 1 oddsid --Soccer Parlay
FROM @tmpCustId t 
WHERE NOT EXISTS (SELECT 1 FROM @tmp_Bettrans b WHERE t.CustId = b.Custid)
UNION ALL
SELECT t.CustId, 0 sum_stake, 99 oddsid -- Mix Sports Parlay
FROM @tmpCustId t 
WHERE NOT EXISTS (SELECT 1 FROM @tmp_Bettrans b WHERE t.CustId = b.Custid)

--MBC
--Soccer; turnover = 0
UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
WHERE EventTypeID = 3 
	AND matchid = 29 
	AND b.sum_stake = 0	

--Soccer; turnover <> 0
UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = PO_History.sum_payout	
FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
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

--Mix sport; turnover = 0
UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 99
WHERE EventTypeID = 4
	AND matchid = 29 
	AND b.sum_stake = 0	

--Mix sport; turnover <> 0
UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = PO_History.sum_payout	
FROM CustLimitBet_MBC l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 99
	CROSS APPLY (
			SELECT SUM(h.PayoutAdjust) AS sum_payout
			FROM CustLimitBetHistory_MBC h WITH (NOLOCK)
				INNER JOIN bettrans b WITH (NOLOCK) ON b.TransId = h.Transid AND b.statusID NOT IN (101)
			WHERE h.CustID = l.CustID
				AND h.Matchid = l.Matchid
				AND h.EventTypeID = l.EventTypeID
		) AS PO_History
WHERE EventTypeID = 4
	AND matchid = 29 
	AND b.sum_stake <> 0
	AND b.sum_stake <> l.AccumTurnover
									
--789y
--Soccer; turnover = 0
UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
WHERE EventTypeID = 3 
	AND matchid = 29 
	AND b.sum_stake = 0	

--Soccer; turnover <> 0
UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = PO_History.sum_payout	
FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
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

--Mix sport; turnover = 0
UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 99
WHERE EventTypeID = 4
	AND matchid = 29 
	AND b.sum_stake = 0	

--Mix sport; turnover <> 0
UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = PO_History.sum_payout	
FROM CustLimitBet_789 l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 99
	CROSS APPLY (
			SELECT SUM(h.PayoutAdjust) AS sum_payout
			FROM CustLimitBetHistory_789 h WITH (NOLOCK)
				INNER JOIN bettrans b WITH (NOLOCK) ON b.TransId = h.Transid AND b.statusID NOT IN (101)
			WHERE h.CustID = l.CustID
				AND h.Matchid = l.Matchid
				AND h.EventTypeID = l.EventTypeID
		) AS PO_History
WHERE EventTypeID = 4
	AND matchid = 29 
	AND b.sum_stake <> 0
	AND b.sum_stake <> l.AccumTurnover
							
--LIC
--Soccer; turnover = 0
UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
WHERE EventTypeID = 3 
	AND matchid = 29 
	AND b.sum_stake = 0	

--Soccer; turnover <> 0
UPDATE l SET l.AccumTurnover = b.sum_stake, l.AccumPayout = PO_History.sum_payout	
FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 1
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

--Mix sport; turnover = 0
UPDATE l SET l.AccumTurnover = 0, l.AccumPayout = 0				
FROM CustLimitBet_LIC l WITH (ROWLOCK, UPDLOCK)		
	INNER JOIN @tmp_Bettrans b ON b.Custid = l.CustID AND b.oddsid = 99
WHERE EventTypeID = 4
	AND matchid = 29 
	AND b.sum_stake = 0	

--Mix sport; turnover <> 0
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
