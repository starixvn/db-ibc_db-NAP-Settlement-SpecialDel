/*<info serverAlias="DBTXN-bodb02"></info>*/
/*
	Created: Tina@20220809
	Task: Initial data for CustLimitBet and CustLimitBetHistory for Outright tickets [Redmine: #167898]   
	DB: DBTXN/bodb02
*/

DECLARE @MaxTransID BIGINT = xxx

CREATE TABLE #Outright (transid BIGINT, MatchID INT, CustID INT, StatusID TINYINT, Stake MONEY, Odds SMALLMONEY)
CREATE TABLE #LICAdjust (MatchID INT, CustID INT, TurnoverAdjust MONEY, PayoutAdjust MONEY, IsFinished BIT DEFAULT 0)
CREATE TABLE #AdjustTemp (MatchID INT, CustID INT, TurnoverAdjust MONEY, PayoutAdjust MONEY)

--Get Outright tickets
INSERT INTO #Outright (transid, MatchID, CustID, StatusID, Stake, Odds)
SELECT b.transid, matchid, custid, statusID, stake, b.odds
FROM bettrans b WITH (NOLOCK)
	INNER JOIN outright ou WITH (NOLOCK) ON b.matchid = ou.orid
WHERE b.srecommend IN (SELECT CustID FROM CustDB.dbo.Dep_CustSuper WITH (NOLOCK)) -- get deposit tickets only
	AND b.bettype = 10 --Outright
	AND b.statusID NOT IN (101) -- 101:reject
	AND ou.oddsstatus <> 'Completed'
	AND b.transid <= @MaxTransID

--Delete transid which exists on History table (customer place bet after deploying)
DELETE ou
FROM #Outright ou
	INNER JOIN CustLimitBetHistory_lic his WITH (NOLOCK) ON ou.transid = his.Transid

--Calculate
INSERT INTO #LICAdjust(MatchID, CustID, TurnoverAdjust, PayoutAdjust)
SELECT ou.MatchID,
	ou.CustID,
	SUM(CASE WHEN ou.StatusID = 102 THEN 0 ELSE ou.Stake END) TurnoverAdjust, 
	SUM(CASE WHEN ou.StatusID = 102 THEN 0 ELSE ou.Stake*ou.Odds END) PayoutAdjust
FROM #Outright ou
GROUP BY ou.MatchID, ou.CustID

-- Insert into LIC group
WHILE (1 = 1)
BEGIN
	TRUNCATE TABLE #AdjustTemp

	UPDATE TOP(1000) #LICAdjust SET IsFinished = 1 
	OUTPUT DELETED.MatchID, deleted.CustID, DELETED.TurnoverAdjust , DELETED.PayoutAdjust
	INTO #AdjustTemp (MatchID, CustID, TurnoverAdjust, PayoutAdjust)
	WHERE IsFinished = 0

	IF @@ROWCOUNT = 0
		BREAK;

	--Main table
	UPDATE lm SET lm.AccumTurnover = (lm.AccumTurnover + at.TurnoverAdjust),
					lm.AccumPayout = (lm.AccumPayout + at.PayoutAdjust)
	FROM CustLimitBet_LIC lm WITH (ROWLOCK,UPDLOCK)
		INNER JOIN #AdjustTemp at ON at.MatchID = lm.Matchid AND at.CustID = lm.CustID AND lm.EventTypeID = 2
	WHERE at.PayoutAdjust <> 0 AND at.TurnoverAdjust <> 0

	INSERT INTO CustLimitBet_LIC(Matchid, CustID, AccumTurnover, AccumPayout, EventTypeID, LastQueueID, ModifiedDate)
	SELECT at.Matchid, at.CustID, at.TurnoverAdjust, at.PayoutAdjust, 2 EventTypeID, 0 LastQueueID, GETDATE() ModifiedDate
	FROM #AdjustTemp at
		LEFT JOIN CustLimitBet_LIC lm WITH (NOLOCK) ON at.MatchID = lm.Matchid AND at.CustID = lm.CustID AND lm.EventTypeID = 2
	WHERE lm.Matchid IS NULL

	--History table
	INSERT INTO CustLimitBetHistory_LIC(Matchid, CustID, Transid, TurnoverAdjust, PayoutAdjust, EventTypeID, CreatedDate)
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


DROP TABLE #LICAdjust
DROP TABLE #AdjustTemp
DROP TABLE #Outright
