/*<info serverAlias="DBTXN-bodb02"></info>*/
/*
	Created: Tina@20210908
	Task: Initial data for CustLimitBet and CustLimitBetHistory for Outright tickets [Redmine: #158073]   
	DB: DBTXN/bodb02
*/

DECLARE @MaxTransID BIGINT = xxx

CREATE TABLE #Outright (transid BIGINT, MatchID INT, CustID INT, StatusID TINYINT, Stake MONEY, Odds SMALLMONEY, [SiteType] TINYINT) --SiteType: 1 -> MBC; 2 -> 789y
CREATE TABLE #789Adjust (MatchID INT, CustID INT, TurnoverAdjust MONEY, PayoutAdjust MONEY, IsFinished BIT DEFAULT 0)
CREATE TABLE #MBCAdjust (MatchID INT, CustID INT, TurnoverAdjust MONEY, PayoutAdjust MONEY, IsFinished BIT DEFAULT 0)
CREATE TABLE #AdjustTemp (MatchID INT, CustID INT, TurnoverAdjust MONEY, PayoutAdjust MONEY)

--Get Outright tickets
INSERT INTO #Outright (transid, MatchID, CustID, StatusID, Stake, Odds)
SELECT b.transid, matchid, custid, statusID, stake, b.odds
FROM bettrans b WITH (NOLOCK)
	INNER JOIN outright ou WITH (NOLOCK) ON b.matchid = ou.orid
WHERE b.srecommend NOT IN (SELECT CustID FROM CustDB.dbo.Dep_CustSuper WITH (NOLOCK)) --only get credit tickets
	AND b.bettype = 10 --Outright
	AND b.statusID NOT IN (101) -- 101:reject
	AND ou.oddsstatus <> 'Completed'
	AND b.transid <= @MaxTransID

--Get Site of customer
UPDATE ou SET ou.SiteType = (CASE WHEN c.[site] = '789y' THEN 2 ELSE 1 END)
FROM #Outright ou 
	INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON ou.CustID = C.CustID

--Delete transid which exists on History table (customer place bet after deploying)
DELETE ou
FROM #Outright ou
	INNER JOIN CustLimitBetHistory_789 his WITH (NOLOCK) ON ou.transid = his.Transid AND ou.SiteType = 2

DELETE ou
FROM #Outright ou
	INNER JOIN CustLimitBetHistory_MBC his WITH (NOLOCK) ON ou.transid = his.Transid AND ou.SiteType = 1

--Calculate
INSERT INTO #789Adjust(MatchID, CustID, TurnoverAdjust, PayoutAdjust)
SELECT ou.MatchID,
	ou.CustID,
	SUM(CASE WHEN ou.StatusID = 102 THEN 0 ELSE ou.Stake END) TurnoverAdjust, 
	SUM(CASE WHEN ou.StatusID = 102 THEN 0 ELSE ou.Stake*ou.Odds END) PayoutAdjust
FROM #Outright ou
WHERE ou.SiteType = 2
GROUP BY ou.MatchID, ou.CustID

INSERT INTO #MBCAdjust(MatchID, CustID, TurnoverAdjust, PayoutAdjust)
SELECT ou.MatchID,
	ou.CustID,
	SUM(CASE WHEN ou.StatusID = 102 THEN 0 ELSE ou.Stake END) TurnoverAdjust, 
	SUM(CASE WHEN ou.StatusID = 102 THEN 0 ELSE ou.Stake*ou.Odds END) PayoutAdjust
FROM #Outright ou
WHERE ou.SiteType = 1
GROUP BY ou.MatchID, ou.CustID

-- Insert into 789y group
WHILE (1 = 1)
BEGIN
	TRUNCATE TABLE #AdjustTemp

	UPDATE TOP(1000) #789Adjust SET IsFinished = 1 
	OUTPUT DELETED.MatchID, deleted.CustID, DELETED.TurnoverAdjust , DELETED.PayoutAdjust
	INTO #AdjustTemp (MatchID, CustID, TurnoverAdjust, PayoutAdjust)
	WHERE IsFinished = 0

	IF @@ROWCOUNT = 0
		BREAK;

	--Main table
	UPDATE lm SET lm.AccumTurnover = (lm.AccumTurnover + at.TurnoverAdjust),
					lm.AccumPayout = (lm.AccumPayout + at.PayoutAdjust)
	FROM CustLimitBet_789 lm WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #AdjustTemp at ON at.MatchID = lm.Matchid AND at.CustID = lm.CustID AND lm.EventTypeID = 2
	WHERE at.PayoutAdjust <> 0 AND at.TurnoverAdjust <> 0

	INSERT INTO CustLimitBet_789(Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate)
	SELECT at.Matchid, at.CustID, at.TurnoverAdjust, at.PayoutAdjust, 2 EventTypeID, 0 LastQueueID, GETDATE() ModifiedDate
	FROM #AdjustTemp at
		LEFT JOIN CustLimitBet_789 lm WITH (NOLOCK) ON at.MatchID = lm.Matchid AND at.CustID = lm.CustID AND lm.EventTypeID = 2
	WHERE lm.Matchid IS NULL

	--History table
	INSERT INTO CustLimitBetHistory_789(Matchid, CustID, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate)
	SELECT ou.MatchID, 
		   ou.CustID, 
		   ou.transid, 
		   ou.Stake TurnoverAdjust,
		   ou.Stake*ou.Odds PayoutAdjust, 
		   2 EventTypeID,
		   GETDATE() CreatedDate
	FROM #Outright ou
		INNER JOIN #AdjustTemp at ON at.MatchID = ou.MatchID AND at.CustID = ou.CustID
	UNION ALL
	SELECT ou.MatchID, 
		   ou.CustID, 
		   ou.transid, 
		   ou.Stake*-1 TurnoverAdjust,
		   ou.Stake*ou.Odds*-1 PayoutAdjust, 
		   2 EventTypeID,
		   GETDATE() CreatedDate
	FROM #Outright ou
		INNER JOIN #AdjustTemp at ON at.MatchID = ou.MatchID AND at.CustID = ou.CustID
	WHERE ou.StatusID = 102 --void
END

--Insert MBC group
WHILE (1 = 1)
BEGIN
	TRUNCATE TABLE #AdjustTemp

	UPDATE TOP(1000) #MBCAdjust SET IsFinished = 1 
	OUTPUT DELETED.MatchID, deleted.CustID, DELETED.TurnoverAdjust , DELETED.PayoutAdjust
	INTO #AdjustTemp (MatchID, CustID, TurnoverAdjust, PayoutAdjust)
	WHERE IsFinished = 0

	IF @@ROWCOUNT = 0
		BREAK;

	--Main table
	UPDATE lm SET lm.AccumTurnover = (lm.AccumTurnover + at.TurnoverAdjust),
					lm.AccumPayout = (lm.AccumPayout + at.PayoutAdjust)
	FROM CustLimitBet_MBC lm WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #AdjustTemp at ON at.MatchID = lm.Matchid AND at.CustID = lm.CustID AND lm.EventTypeID = 2
	WHERE at.PayoutAdjust <> 0 AND at.TurnoverAdjust <> 0

	INSERT INTO CustLimitBet_MBC(Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate)
	SELECT at.Matchid, at.CustID, at.TurnoverAdjust, at.PayoutAdjust, 2 EventTypeID, 0 LastQueueID, GETDATE() ModifiedDate
	FROM #AdjustTemp at
		LEFT JOIN CustLimitBet_MBC lm WITH (NOLOCK) ON at.MatchID = lm.Matchid AND at.CustID = lm.CustID AND lm.EventTypeID = 2
	WHERE lm.Matchid IS NULL

	--History table
	INSERT INTO CustLimitBetHistory_MBC(Matchid, CustID, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate)
	SELECT ou.MatchID, 
		   ou.CustID, 
		   ou.transid, 
		   ou.Stake TurnoverAdjust,
		   ou.Stake*ou.Odds PayoutAdjust, 
		   2 EventTypeID,
		   GETDATE() CreatedDate
	FROM #Outright ou
		INNER JOIN #AdjustTemp at ON at.MatchID = ou.MatchID AND at.CustID = ou.CustID
	UNION ALL
	SELECT ou.MatchID, 
		   ou.CustID, 
		   ou.transid, 
		   ou.Stake*-1 TurnoverAdjust,
		   ou.Stake*ou.Odds*-1 PayoutAdjust, 
		   2 EventTypeID,
		   GETDATE() CreatedDate
	FROM #Outright ou
		INNER JOIN #AdjustTemp at ON at.MatchID = ou.MatchID AND at.CustID = ou.CustID
	WHERE ou.StatusID = 102 --void
END

DROP TABLE #789Adjust
DROP TABLE #AdjustTemp
DROP TABLE #MBCAdjust
DROP TABLE #Outright
