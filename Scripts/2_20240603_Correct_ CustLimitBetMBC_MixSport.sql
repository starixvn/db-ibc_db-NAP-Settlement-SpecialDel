/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240632@Louisa
	Task: Correct CustLimitBet_MBC when no running ticket [Redmine:#206061]
	DB:  DBSIC.bodb02
*/
USE bodb02
GO
 
CREATE TABLE #Temp_CustID(
	ID INT IDENTITY (1,1) PRIMARY KEY,
	CustID INT
)


INSERT INTO #Temp_CustID (CustID)
SELECT DISTINCt CustID
FROM CustLimitBet_MBC t WITH (Nolock)
WHERE t.Matchid = 29 
	AND t.AccumPayout < 0
	AND t.EventTypeID = 4
	AND NOT EXISTS (
			SELECT TOP 1 1 
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE b.custid = t.CustID
				AND b.matchid = 29
				AND b.statusID < 2
				AND b.oddsid = 99
		)

------ info for deployer
DECLARE @StartRow INT 
		, @MaxRow INT  
		, @CustID	INT
		,@debug_message VARCHAR(500)

SET @MaxRow = (SELECT MAX(ID) FROM #Temp_CustID)
SELECT @StartRow = 1

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
		SELECT @CustID = CustID 
		FROM #Temp_CustID
		WHERE ID = @StartRow

		UPDATE t
		SET AccumTurnover = 0
			, AccumPayout = 0
		FROM CustLimitBet_MBC t WITH (ROWLOCK, UPDLOCK)
		WHERE t.custid = @custid 
			AND t.Matchid = 29 
			AND t.AccumPayout < 0
			AND t.EventTypeID = 4
			AND NOT EXISTS (
					SELECT TOP 1 1 
					FROM dbo.bettrans b WITH(NOLOCK)
					WHERE b.custid = @custid
						AND b.matchid = 29
						AND b.statusID < 2
						AND b.oddsid = 99
				)

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121) +' | CustId:' + CAST(@custid AS VARCHAR(20) )			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
		IF @StartRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.005' --optional

		SET @StartRow = @StartRow + 1

END

DROP TABLE #Temp_CustID
