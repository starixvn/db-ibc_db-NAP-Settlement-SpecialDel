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
		, @MaxTransId BIGINT


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
    PayoutAdjust MONEY,
	ExtraInfo VARCHAR(1000)
);

--Get running match
CREATE TABLE #RunningMatch (matchid INT PRIMARY KEY, sporttype SMALLINT)

INSERT INTO #RunningMatch(matchid, sporttype)
SELECT m.matchid, m.sporttype
FROM dbo.[match] m WITH (NOLOCK)
WHERE m.eventstatus = 'running'
	AND m.sporttype <= 99
	AND m.sporttype NOT IN (43, 44) --No need to process for Esports & MuayThai

SELECT @MaxTransId = MAX(TransId) FROM dbo.bettrans b WITH (NOLOCK)

-- Get all qualifying TransIds upfront
INSERT INTO #TransIdsToProcess (TransId, CustID, MatchId, EventTypeID, BetType, SiteType, PayoutAdjust, ExtraInfo)
SELECT 
    bt.TransId,
    bt.CustID,
    bt.MatchId,
    1 AS EventTypeID,
    bt.BetType,
	IIF(s.sitelabel = '789y', 2, 1) AS SiteType,
	ISNULL(
		CAST(
			CAST(bt.ExtraInfo AS XML).value('(/p1/@pa)[1]', 'VARCHAR(50)') AS MONEY
		), 
		0
	) AS PayoutAdjust
	,bt.ExtraInfo
FROM #RunningMatch m
	INNER JOIN dbo.bettrans bt WITH (NOLOCK) ON bt.matchid = m.matchid
	INNER JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = bt.custid
	INNER JOIN CustDB.dbo.site s WITH (NOLOCK) ON s.site = c.site
WHERE bt.StatusId IN (0,1)  -- Running bets
	AND bt.transid <= @MaxTransId
	--list bettypes in function f_CustLimitBet_AccumPayout_Exclude
	AND bt.bettype IN (1,3,5,7,8,15,20,21,153,501,609,610,612,701,704,705,9400,9404,9405,9406,9407,9408,9409,9522,9604,8800,8801,8802,8803,8804,8805,8806,8807,8808,8809,8810,8811,8812,8814,8815,8816,8817,8818,8819,8820,8821,8823,8824,8827,8828,8829,8830,8832,8833)

--Get missing payout value transid
DECLARE @tmp_MissingPayoutTrans AS TABLE (TransIds BIGINT, ExtraInfo VARCHAR(1000))
DELETE #TransIdsToProcess OUTPUT DELETED.TransId, DELETED.ExtraInfo INTO @tmp_MissingPayoutTrans (TransIds, ExtraInfo)
WHERE PayoutAdjust = 0

--Remove transid already update payout to avoid script run multiple times
DELETE t
FROM #TransIdsToProcess t
WHERE EXISTS (
    SELECT TOP 1 1
    FROM dbo.CustLimitBetHistory_MBC m1 WITH (NOLOCK)
    WHERE m1.Matchid = t.MatchId 
        AND m1.CustID = t.CustID 
        AND m1.Transid = t.TransId
        AND m1.PayoutAdjust <> 0
)

DELETE t
FROM #TransIdsToProcess t
WHERE EXISTS (
    SELECT TOP 1 1
    FROM dbo.CustLimitBetHistory_789 m2 WITH (NOLOCK)
    WHERE m2.Matchid = t.MatchId 
        AND m2.CustID = t.CustID 
        AND m2.Transid = t.TransId
        AND m2.PayoutAdjust <> 0
)

IF NOT EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess)
BEGIN
    PRINT 'No TransIds found to process.'
    RETURN
END

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
			SET PayoutAdjust = batch.PayoutAdjust 
			OUTPUT inserted.Transid, 1 INTO #UpdatedTransIds(TransId, sitetype)
			FROM dbo.CustLimitBetHistory_MBC clbh WITH (ROWLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = clbh.Transid
				INNER JOIN #TransIdsToProcess batch ON clbh.Matchid = batch.MatchId AND clbh.CustID = batch.CustID AND clbh.Transid = batch.TransId
			WHERE batch.Id BETWEEN @StartRow AND @StopRow
				AND batch.SiteType = 1
				AND b.statusID IN (0,1)
				AND clbh.PayoutAdjust = 0
		END

		--789y
		IF EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess WHERE sitetype = 2)
		BEGIN
			UPDATE clbh
			SET PayoutAdjust = batch.PayoutAdjust
			OUTPUT inserted.Transid, 2 INTO #UpdatedTransIds(TransId, sitetype)
			FROM dbo.CustLimitBetHistory_789 clbh WITH (ROWLOCK)
				INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = clbh.Transid
				INNER JOIN #TransIdsToProcess batch ON clbh.Matchid = batch.MatchId AND clbh.CustID = batch.CustID AND clbh.Transid = batch.TransId
			WHERE batch.Id BETWEEN @StartRow AND @StopRow
				AND batch.SiteType = 2
				AND b.statusID IN (0,1)
				AND clbh.PayoutAdjust = 0
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
SET @MaxRow = (SELECT MAX(ID) FROM #TransIdsToProcess)
SET @Threshold = 2000

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
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t1.TransId
					WHERE t1.Id BETWEEN @StartRow AND @StopRow
						AND t1.SiteType = 1
						AND t.Matchid = t1.MatchId AND t.CustID = t1.CustId AND t.EventTypeID = t1.EventTypeID
						AND b.statusID IN (0,1) --running bet
					GROUP BY t1.MatchId, t1.CustId, t1.EventTypeID
				)tmp
		END

		--789y
		IF EXISTS (SELECT TOP 1 1 FROM #TransIdsToProcess WHERE sitetype = 2)
		BEGIN
			UPDATE t SET t.AccumPayout = (t.AccumPayout + tmp.AccumPayout)
			FROM dbo.CustLimitBet_789 t WITH (ROWLOCK)
				CROSS APPLY (
					SELECT SUM(t1.PayoutAdjust) AS AccumPayout
					FROM #TransIdsToProcess t1
						INNER JOIN dbo.bettrans b WITH (NOLOCK) ON b.TransId = t1.TransId
					WHERE t1.Id BETWEEN @StartRow AND @StopRow
						AND t1.SiteType = 2
						AND t.Matchid = t1.MatchId AND t.CustID = t1.CustId AND t.EventTypeID = t1.EventTypeID
						AND b.statusID IN (0,1) --running bet
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

--Return transid payout = 0
IF EXISTS (SELECT TOP 1 1 FROM @tmp_MissingPayoutTrans)
BEGIN
	SELECT t.TransIds, t.ExtraInfo
	FROM @tmp_MissingPayoutTrans t
END

DROP TABLE #TransIdsToProcess
DROP TABLE #UpdatedTransIds
DROP TABLE #RunningMatch
