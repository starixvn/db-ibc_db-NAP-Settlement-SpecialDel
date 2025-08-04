/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250801@Max
	Task: Credit - Max Payout Per Match for all bettypes for all sports [Redmine:#230652]
	DB: DBSIC/bodb02
*/

USE bodb02

DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch


CREATE TABLE #UpdatedTransIds (
    TransId BIGINT PRIMARY KEY
	,sitetype TINYINT
);

CREATE TABLE #TransIdsToProcess (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    TransId BIGINT,
    CustID INT,
    MatchId INT,
    EventTypeID TINYINT,
    BetType SMALLINT,
    SiteType TINYINT,
    PayoutAdjust MONEY
);

-- Get all qualifying TransIds upfront
INSERT INTO #TransIdsToProcess (TransId, CustID, MatchId, EventTypeID, BetType, SiteType, PayoutAdjust)
SELECT 
    bt.TransId,
    bt.CustID,
    bt.MatchId,
    CASE WHEN bt.BetType = 10 THEN 2 ELSE 1 END AS EventTypeID,
    bt.BetType,
	t.sitetype,
	ISNULL(
		CAST(
			CAST(bt.ExtraInfo AS XML).value('(/p1/@pa)[1]', 'VARCHAR(50)') AS MONEY
		), 
		0
	) AS PayoutAdjust	
FROM dbo.BetTrans bt WITH (NOLOCK)
INNER JOIN dbo.Match m WITH (NOLOCK) ON bt.MatchId = m.MatchId
CROSS APPLY (
		SELECT 1 AS sitetype
		FROM dbo.CustLimitBetHistory_MBC mb WITH (NOLOCK)
		WHERE mb.Matchid = bt.matchid AND mb.CustID = bt.custid AND mb.Transid = bt.TransId
			AND mb.PayoutAdjust = 0

		UNION ALL
		SELECT 2 AS sitetype
		FROM dbo.CustLimitBetHistory_789 m1 WITH (NOLOCK)
		WHERE m1.Matchid = bt.matchid AND m1.CustID = m1.custid AND m1.Transid = bt.TransId
			AND m1.PayoutAdjust = 0
)t
INNER JOIN dbo.f_CustLimitBet_AccumPayout_Exclude() excl ON bt.BetType = excl.BetType
WHERE bt.StatusId = 0  -- Running bets
  AND m.EventStatus = 'running'  -- Running matches

DELETE #TransIdsToProcess WHERE PayoutAdjust = 0

IF NOT EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess)
BEGIN
    PRINT 'No TransIds found to process.'
    RETURN
END

SET @MaxRow = (SELECT MAX(ID) FROM #TransIdsToProcess)
SET @Threshold = 20000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
    BEGIN TRY
		--MBC
		IF EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess WHERE sitetype = 1)
		BEGIN
			UPDATE t SET t.AccumPayout = (t.AccumPayout + tmp.AccumPayout)
			FROM dbo.CustLimitBet_MBC t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT SUM(t1.PayoutAdjust) AS AccumPayout
					FROM #TransIdsToProcess t1
					WHERE t1.Id BETWEEN @StartRow AND @StopRow
						AND t1.SiteType = 1
						AND t.Matchid = t1.MatchId AND t.CustID = t1.CustId AND t.EventTypeID = t1.EventTypeID
					GROUP BY t1.MatchId, t1.CustId, t1.EventTypeID
				)tmp

			UPDATE clbh
			SET PayoutAdjust = batch.PayoutAdjust 
			OUTPUT inserted.Transid, 1 INTO #UpdatedTransIds(TransId, sitetype)
			FROM dbo.CustLimitBetHistory_MBC clbh WITH (ROWLOCK)
				INNER JOIN #TransIdsToProcess batch ON clbh.Matchid = batch.MatchId AND clbh.CustID = batch.CustID AND clbh.Transid = batch.TransId
			WHERE batch.Id BETWEEN @StartRow AND @StopRow
			AND batch.SiteType = 1
		END

		--789y
		IF EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess WHERE sitetype = 2)
		BEGIN
			UPDATE t SET t.AccumPayout = (t.AccumPayout + tmp.AccumPayout)
			FROM dbo.CustLimitBet_789 t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT SUM(t1.PayoutAdjust) AS AccumPayout
					FROM #TransIdsToProcess t1
					WHERE t1.Id BETWEEN @StartRow AND @StopRow
						AND t1.SiteType = 2
						AND t.Matchid = t1.MatchId AND t.CustID = t1.CustId AND t.EventTypeID = t1.EventTypeID
					GROUP BY t1.MatchId, t1.CustId, t1.EventTypeID
				)tmp

			UPDATE clbh
			SET PayoutAdjust = batch.PayoutAdjust
			OUTPUT inserted.Transid, 2 INTO #UpdatedTransIds(TransId, sitetype)
			FROM dbo.CustLimitBetHistory_789 clbh WITH (ROWLOCK)
				INNER JOIN #TransIdsToProcess batch ON clbh.TransId = batch.TransId
			WHERE batch.Id BETWEEN @StartRow AND @StopRow
			AND batch.SiteType = 2
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

-- Return list of updated TransIds
-- Check row count for each TransId - MBC
DECLARE @tmp_AdjustVoidedTransId AS TABLE (TransId BIGINT, MatchId INT, CustId INT)
INSERT INTO @tmp_AdjustVoidedTransId (TransId, MatchId, CustId)
SELECT 
    clbh.TransId, Matchid, CustID
FROM dbo.CustLimitBetHistory_MBC clbh WITH (NOLOCK)
	INNER JOIN #UpdatedTransIds ut ON clbh.TransId = ut.TransId AND ut.sitetype = 1
GROUP BY clbh.TransId, Matchid, CustId
HAVING COUNT(*) = 2
ORDER BY clbh.TransId, matchid, custid

IF @@ROWCOUNT > 0
BEGIN
	UPDATE t SET t.AccumPayout = (t.AccumPayout + tmp.AccumPayout)
	FROM dbo.CustLimitBet_MBC t WITH (ROWLOCK)
		CROSS APPLY (
			SELECT -SUM(tmpsum.AccumPayout) AS AccumPayout
				,tmpsum.MatchId, tmpsum.CustId
			FROM
			(
				SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t1.MatchId, t1.CustId, t1.transid, t2.EventTypeID
				FROM @tmp_AdjustVoidedTransId t1
					INNER JOIN dbo.CustLimitBetHistory_MBC t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = t1.CustId and t2.Transid = t1.transid
				GROUP BY t1.Matchid, t1.CustId, t1.transid, t2.EventTypeID
			)tmpsum
			WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
			GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
		)tmp

	DELETE @tmp_AdjustVoidedTransId
END

-- Check row count for each TransId - 789
DELETE @tmp_AdjustVoidedTransId
INSERT INTO @tmp_AdjustVoidedTransId (TransId, MatchId, CustId)
SELECT 
    clbh.TransId, Matchid, CustID
FROM dbo.CustLimitBetHistory_789 clbh WITH (NOLOCK)
	INNER JOIN #UpdatedTransIds ut ON clbh.TransId = ut.TransId AND ut.sitetype = 2
GROUP BY clbh.TransId, matchid, custid
HAVING COUNT(*) = 2
ORDER BY clbh.TransId, matchid, custid

IF @@ROWCOUNT > 0
BEGIN
	UPDATE t SET t.AccumPayout = (t.AccumPayout + tmp.AccumPayout)
	FROM dbo.CustLimitBet_789 t WITH (ROWLOCK)
		CROSS APPLY (
			SELECT -SUM(tmpsum.AccumPayout) AS AccumPayout
				,tmpsum.MatchId, tmpsum.CustId
			FROM
			(
				SELECT MAX(t2.TurnoverAdjust) AS AccumTurnover, MAX(t2.PayoutAdjust) AS AccumPayout, t1.MatchId, t1.CustId, t1.transid, t2.EventTypeID
				FROM @tmp_AdjustVoidedTransId t1
					INNER JOIN dbo.CustLimitBetHistory_789 t2 WITH (NOLOCK) ON t2.Matchid = t1.MatchId and t2.CustID = t1.CustId and t2.Transid = t1.transid
				GROUP BY t1.Matchid, t1.CustId, t1.transid, t2.EventTypeID
			)tmpsum
			WHERE t.Matchid = tmpsum.MatchId AND t.CustID = tmpsum.CustId AND t.EventTypeID = tmpsum.EventTypeID
			GROUP BY tmpsum.MatchId, tmpsum.CustId, tmpsum.EventTypeID
		)tmp

	DELETE @tmp_AdjustVoidedTransId
END

DROP TABLE #TransIdsToProcess
DROP TABLE #UpdatedTransIds
