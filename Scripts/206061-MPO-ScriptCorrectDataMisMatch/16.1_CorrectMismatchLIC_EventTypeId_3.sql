/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240604@Max
	Task: Update if mismatch current data between main table vs history table & running parlay tickets in bettrans CustLitmitBet_LIC - EventTypeID = 3 [Redmine:#206061]
	DB:  DBSID.bodb02
*/
USE bodb02
GO

SET NOCOUNT ON;
 
CREATE TABLE #Temp_CustID(
	ID INT IDENTITY (1,1) PRIMARY KEY,
	CustID INT
)

INSERT INTO #Temp_CustID (CustID)
SELECT DISTINCT c.CustID
FROM bettrans c WITH(NOLOCK)
	INNER JOIN CustLimitBetHistory_LIC h WITH (NOLOCK) ON h.Transid = c.TransId
WHERE c.matchid = 29 
	AND c.oddsid = 1
	AND c.ruben = 0
	AND h.EventTypeID = 3

------ info for deployer
DECLARE @StartRow INT 
		,@MaxRow INT
		,@custid INT
		,@debug_message VARCHAR(500)
		, @Threshold INT  -- the number of each batch
		, @StopRow INT 

SET @MaxRow = (SELECT MAX(ID) FROM #Temp_CustID)

SET @Threshold = 500

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN

		;WITH cte AS
		(
			SELECT tmp.CustID
				, ISNULL(SUM(PayoutAdjust),0) as PayoutAdjust
				, ISNULL(SUM(TurnoverAdjust),0) as TurnoverAdjust
			FROM (
					SELECT h.CustID
						, h.transid
						, ABS(MAX(h.PayoutAdjust)) as PayoutAdjust
						, ABS(MAX(h.TurnoverAdjust)) as TurnoverAdjust
					FROM bettrans b with (NOLOCK)	
						INNER JOIN #Temp_CustID c ON c.CustID = b.custid
						INNER JOIN CustLimitBetHistory_LIC h WITH(NOLOCK)
							ON h.Transid = b.transid 
					WHERE c.ID BETWEEN @StartRow AND @StopRow
						AND b.ruben = 0
						AND h.Matchid = 29 
						AND b.oddsid = 1
						AND h.EventTypeID = 3
					GROUP BY h.transid, h.CustID
				) AS tmp
			GROUP BY tmp.CustID
		)
		
		UPDATE t
		SET AccumPayout = t1.PayoutAdjust 
			, AccumTurnover = t1.TurnoverAdjust
		FROM CustLimitBet_LIC t WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #Temp_CustID c ON c.CustID = t.CustID
			CROSS APPLY ( SELECT PayoutAdjust, TurnoverAdjust FROM cte t1 WHERE t1.CustID = t.CustID ) AS t1
		WHERE c.ID BETWEEN @StartRow AND @StopRow
			AND t.AccumPayout <> t1.PayoutAdjust
			AND t.matchid = 29
			AND t.EventTypeID = 3

		IF @@ROWCOUNT > 0
		BEGIN
			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121) +' | id:' + CAST(@StartRow AS VARCHAR(20)) + CAST(@StopRow AS VARCHAR(20) )			
			RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		END

		IF @StopRow = @MaxRow BREAK

		--WAITFOR DELAY '00:00:00.005' --optional

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

END

DROP TABLE #Temp_CustID