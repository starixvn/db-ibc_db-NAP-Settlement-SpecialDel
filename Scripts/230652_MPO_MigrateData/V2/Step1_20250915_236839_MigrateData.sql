/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 22050912@Max
	Task: [Synegy] - Support Max Payout Win Per match adjustment for Phase 1_Credit [Redmine: #236839]
	DB: DBSIC/bodb02
*/

USE bodb02

DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
		, @MaxTransId BIGINT


CREATE TABLE #UpdatedTransIds (
	Id INT IDENTITY(1,1) PRIMARY KEY
    ,TransId BIGINT
	,DiffAmount MONEY
	,sitetype TINYINT
	,CustID INT
    ,MatchId INT
    ,EventTypeID TINYINT
);

CREATE TABLE #TransIdsToProcess (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    TransId BIGINT,
    CustID INT,
    MatchId INT,
    EventTypeID TINYINT,
    BetType SMALLINT,
    SiteType TINYINT,
    PayoutAdjust MONEY,
	ExtraInfo VARCHAR(1000),
	Actual_stake MONEY
);

--Get running match
CREATE TABLE #RunningMatch (matchid INT PRIMARY KEY, sporttype SMALLINT)

INSERT INTO #RunningMatch(matchid, sporttype)
SELECT m.matchid, m.sporttype
FROM dbo.[match] m WITH (NOLOCK)
WHERE m.eventstatus = 'running'
	AND m.sporttype <= 99

SELECT @MaxTransId = MAX(TransId) FROM dbo.bettrans b WITH (NOLOCK)

PRINT @MaxTransId

-- Get all qualifying TransIds upfront
INSERT INTO #TransIdsToProcess (TransId, CustID, MatchId, EventTypeID, BetType, SiteType, PayoutAdjust, ExtraInfo, Actual_stake)
SELECT 
    bt.TransId,
    bt.CustID,
    bt.MatchId,
    CASE WHEN bettype = 38 THEN 5 ELSE 1 END AS EventTypeID,
    bt.BetType,
	IIF(s.sitelabel = '789y', 2, 1) AS SiteType,
	ISNULL(
		CAST(
			CAST(bt.ExtraInfo AS XML).value('(/p1/@pa)[1]', 'VARCHAR(50)') AS MONEY
		), 
		0
	) AS PayoutAdjust
	,bt.ExtraInfo
	,bt.actual_stake
FROM #RunningMatch m
	INNER JOIN dbo.bettrans bt WITH (NOLOCK) ON bt.matchid = m.matchid
	INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = bt.custid
	INNER JOIN CustDB.dbo.site s WITH (NOLOCK) ON s.site = c.site
WHERE bt.StatusId IN (0,1)  -- Running bets
	AND bt.transid <= @MaxTransId

--Remove transid already update payout to avoid script run multiple times
DELETE t
FROM #TransIdsToProcess t
WHERE EXISTS (
    SELECT TOP 1 1
    FROM dbo.CustLimitBetHistory_MBC m1 WITH (NOLOCK)
    WHERE m1.Matchid = t.MatchId 
        AND m1.CustID = t.CustID 
        AND m1.Transid = t.TransId
        AND m1.PayoutAdjust = (t.PayoutAdjust - t.Actual_stake)
)

DELETE t
FROM #TransIdsToProcess t
WHERE EXISTS (
    SELECT TOP 1 1
    FROM dbo.CustLimitBetHistory_789 m2 WITH (NOLOCK)
    WHERE m2.Matchid = t.MatchId 
        AND m2.CustID = t.CustID 
        AND m2.Transid = t.TransId
        AND m2.PayoutAdjust = (t.PayoutAdjust - t.Actual_stake)
)

IF NOT EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess)
BEGIN
    PRINT 'No TransIds found to process.'
    RETURN
END

/*==================PROCESS DATA=========================*/
--Get missing payout value transid
DECLARE @tmp_MissingPayoutTrans AS TABLE (TransIds BIGINT, ExtraInfo VARCHAR(1000))
DELETE #TransIdsToProcess OUTPUT DELETED.TransId, DELETED.ExtraInfo INTO @tmp_MissingPayoutTrans (TransIds, ExtraInfo)
WHERE PayoutAdjust = 0

SET @MaxRow = (SELECT MAX(ID) FROM #TransIdsToProcess)
SET @Threshold = 2000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

--Update history
WHILE (@MaxRow IS NOT NULL)
BEGIN
    BEGIN TRY
		--MBC
		IF EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess WHERE sitetype = 1)
		BEGIN			
			UPDATE clbh
			SET PayoutAdjust = CASE WHEN clbh.PayoutAdjust = 0 THEN batch.PayoutAdjust - batch.Actual_stake
									WHEN clbh.PayoutAdjust = batch.PayoutAdjust THEN clbh.PayoutAdjust - batch.Actual_stake
									ELSE clbh.PayoutAdjust
								END
			OUTPUT inserted.Transid, 1, inserted.PayoutAdjust - deleted.PayoutAdjust, inserted.Matchid, inserted.CustID, inserted.EventTypeID
				INTO #UpdatedTransIds(TransId, sitetype, DiffAmount, MatchId, CustID, EventTypeID)
			FROM dbo.CustLimitBetHistory_MBC clbh WITH (ROWLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = clbh.Transid
				INNER JOIN #TransIdsToProcess batch ON clbh.Matchid = batch.MatchId AND clbh.CustID = batch.CustID AND clbh.Transid = batch.TransId
			WHERE batch.Id BETWEEN @StartRow AND @StopRow
				AND batch.SiteType = 1
				AND b.statusID IN (0,1)
		END

		--789y
		IF EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess WHERE sitetype = 2)
		BEGIN
			UPDATE clbh
			SET PayoutAdjust = CASE WHEN clbh.PayoutAdjust = 0 THEN batch.PayoutAdjust - batch.Actual_stake
									WHEN clbh.PayoutAdjust = batch.PayoutAdjust THEN clbh.PayoutAdjust - batch.Actual_stake
									ELSE clbh.PayoutAdjust
								END
			OUTPUT inserted.Transid, 2, inserted.PayoutAdjust - deleted.PayoutAdjust, inserted.Matchid, inserted.CustID, inserted.EventTypeID
				INTO #UpdatedTransIds(TransId, sitetype, DiffAmount, MatchId, CustID, EventTypeID)
			FROM dbo.CustLimitBetHistory_789 clbh WITH (ROWLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = clbh.Transid
				INNER JOIN #TransIdsToProcess batch ON clbh.Matchid = batch.MatchId AND clbh.CustID = batch.CustID AND clbh.Transid = batch.TransId
			WHERE batch.Id BETWEEN @StartRow AND @StopRow
				AND batch.SiteType = 2
				AND b.statusID IN (0,1)
		END

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.100'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF  @StopRow >= @MaxRow
		BEGIN
			SET @StopRow = @MaxRow
		END

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN
	END CATCH
    
END

--update main
SET @MaxRow = (SELECT MAX(ID) FROM #UpdatedTransIds)
SET @Threshold = 2000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold
WHILE (@MaxRow IS NOT NULL)
BEGIN
	PRINT @StartRow
	PRINT @StopRow

    BEGIN TRY
		--MBC
		IF EXISTS (SELECT TOP 1 1 FROM #UpdatedTransIds WHERE sitetype = 1)
		BEGIN
			UPDATE t SET t.AccumPayout = (t.AccumPayout + tmp.AccumDiffAmount)
			FROM dbo.CustLimitBet_MBC t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT SUM(t1.DiffAmount) AS AccumDiffAmount
					FROM #UpdatedTransIds t1
					WHERE t1.Id BETWEEN @StartRow AND @StopRow
						AND t1.SiteType = 1
						AND t.Matchid = t1.MatchId AND t.CustID = t1.CustId AND t.EventTypeID = t1.EventTypeID
					GROUP BY t1.MatchId, t1.CustId, t1.EventTypeID
				)tmp
		END

		--789y
		IF EXISTS (SELECT TOP 1 1 FROM #UpdatedTransIds WHERE sitetype = 2)
		BEGIN
			UPDATE t SET t.AccumPayout = (t.AccumPayout + tmp.AccumDiffAmount)
			FROM dbo.CustLimitBet_789 t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT SUM(t1.DiffAmount) AS AccumDiffAmount
					FROM #UpdatedTransIds t1
					WHERE t1.Id BETWEEN @StartRow AND @StopRow
						AND t1.SiteType = 2
						AND t.Matchid = t1.MatchId AND t.CustID = t1.CustId AND t.EventTypeID = t1.EventTypeID
					GROUP BY t1.MatchId, t1.CustId, t1.EventTypeID
				)tmp
		END

		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.100'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

	END TRY
	BEGIN CATCH
		SELECT ERROR_MESSAGE()
		RETURN
	END CATCH
    
END

/*==================END=========================*/

--Return output data updated
SELECT MIN(TransId) AS Min_Upd, Max(TransId) AS Max_Upd, COUNT(1) AS CntTransId
FROM #UpdatedTransIds

--Return transid payout = 0
IF EXISTS (SELECT TOP 1 1 FROM @tmp_MissingPayoutTrans)
BEGIN
	SELECT t.TransIds, t.ExtraInfo
	FROM @tmp_MissingPayoutTrans t
END

DROP TABLE #TransIdsToProcess
DROP TABLE #UpdatedTransIds
DROP TABLE #RunningMatch
