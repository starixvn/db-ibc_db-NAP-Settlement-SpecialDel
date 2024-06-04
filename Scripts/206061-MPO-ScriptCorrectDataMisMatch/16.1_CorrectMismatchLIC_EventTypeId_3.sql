/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240604@Max
	Task: Update if mismatch current data between main table vs history table & running parlay tickets in bettrans CustLitmitBet_LIC - EventTypeID = 3 [Redmine:#206061]
	DB:  DBSID.bodb02
*/
USE bodb02
GO
 
CREATE TABLE #Temp_CustID(
	ID INT IDENTITY (1,1) PRIMARY KEY,
	CustID INT
)

INSERT INTO #Temp_CustID (CustID)
SELECT DISTINCT c.CustID
FROM bettrans c WITH(NOLOCK)
WHERE matchid = 29 
	AND c.oddsid = 1

------ info for deployer
DECLARE @StartRow INT 
		,@MaxRow INT
		,@custid INT
		,@debug_message VARCHAR(500)

SET @MaxRow = (SELECT MAX(ID)
 FROM #Temp_CustID)
SELECT @StartRow = 1

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
		SELECT @CustID = CustID 
		FROM #Temp_CustID
		WHERE ID = @StartRow

		;WITH cte AS
		(
			SELECT SUM(PayoutAdjust) as PayoutAdjust, SUM(TurnoverAdjust) as TurnoverAdjust
			FROM (
					SELECT h.transid
						, ABS(MAX(h.PayoutAdjust)) as PayoutAdjust
						, ABS(MAX(h.TurnoverAdjust)) as TurnoverAdjust
					FROM bettrans b with (NOLOCK) 
						INNER JOIN CustLimitBetHistory_LIC h WITH(NOLOCK)
							ON h.Transid = b.transid 
					WHERE b.ruben = 0
						AND h.Matchid = 29 
						AND b.oddsid = 1
						AND b.custid = @custid
						AND h.EventTypeID = 3
					GROUP BY h.transid
				) AS tmp
	
		)
		
		UPDATE t
		SET AccumPayout = t1.PayoutAdjust 
			, AccumTurnover = t1.TurnoverAdjust
		FROM CustLimitBet_LIC t WITH(ROWLOCK, UPDLOCK)
			CROSS APPLY ( SELECT PayoutAdjust, TurnoverAdjust FROM cte ) AS t1
		WHERE t.AccumPayout <> t1.PayoutAdjust
			AND t.custid = @custid 
			AND t.matchid = 29
			AND t.EventTypeID = 3

		IF @@ROWCOUNT > 0
		BEGIN
			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121) +' | CustId:' + CAST(@custid AS VARCHAR(20) )			
			RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		END

		IF @StartRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.005' --optional

		SET @StartRow = @StartRow + 1

END

DROP TABLE #Temp_CustID