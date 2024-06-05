/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240604@Max
	Task: Resert 0 if not exists in bettrans CustLitmitBet_LIC - EventTypeID = 3 [Redmine:#206061]
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
SELECT DISTINCT CustID
FROM CustLimitBet_LIC t WITH (Nolock)
WHERE  t.matchid = 29
	AND t.EventTypeID = 3
	AND t.AccumTurnover <> 0
	AND NOT EXISTS (SELECT TOP 1 1 AS IsExists FROM bettrans b WITH (NOLOCK) WHERE b.custid = t.CustID AND b.matchid = 29 AND b.oddsid = 1 AND b.ruben = 0)

------ info for deployer
DECLARE @StartRow INT 
		, @MaxRow INT  
		, @CustID	INT
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
		UPDATE t
		SET AccumPayout = 0
			, AccumTurnover = 0
		FROM CustLimitBet_LIC t WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #Temp_CustID c ON t.CustID = t.CustID
		WHERE  c.ID BETWEEN @StartRow AND @StopRow
			AND t.matchid = 29
			AND t.EventTypeID = 3
			AND t.AccumTurnover <> 0

		IF @@ROWCOUNT > 0
		BEGIN
			SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121) +' | id:' + CAST(@StartRow AS VARCHAR(20)) + ' - ' + CAST(@StopRow AS VARCHAR(20) )			
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


