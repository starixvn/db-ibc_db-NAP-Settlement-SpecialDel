/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240604@Louisa
	Task: Correct CustLimitBet_LIC when exists running ticket [Redmine:#206061]
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
FROM CustLimitBet_LIC c WITH(NOLOCK)
	CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK) WHERE custid = c.CustID and oddsid = 1 and matchid = 29 and ruben = 0 ) AS t
WHERE matchid = 29 
	AND c.AccumPayout < 0
	AND c.EventTypeID = 3

------ info for deployer
DECLARE @StartRow INT 
		,@MaxRow INT
		,@custid INT
		,@debug_message VARCHAR(500)

SET @MaxRow = (SELECT MAX(ID) FROM #Temp_CustID)
SELECT @StartRow = 1

WHILE (@MaxRow IS NOT NULL)
BEGIN
	
		SELECT @CustID = CustID 
		FROM #Temp_CustID
		WHERE ID = @StartRow

		;WITH cte1 AS
		(
			SELECT COUNT(1) AS bettran_cnt
			FROM bettrans b WITH(NOLOCK)
			WHERE b.statusID in (0,1) 
				AND b.Matchid = 29
				AND b.oddsid = 1
				AND b.custid = @custid
		)
		, cte2 AS
		(
			SELECT COUNT(distinct h.transid) as history_cnt
			FROM CustLimitBetHistory_LIC h with (nolock)
				INNER JOIN bettrans b WITH(NOLOCK)
					ON h.Transid = b.transid 
						AND b.matchid = 29
			WHERE h.custid = @custid
				AND h.matchid = 29
				AND b.oddsid = 1
				AND b.statusID in (0,1)
		)
		, cte3 AS
		(
			SELECT SUM(PayoutAdjust) as PayoutAdjust, SUM(TurnoverAdjust) as TurnoverAdjust
			FROM (
					SELECT h.transid
						, MAX(h.PayoutAdjust) as PayoutAdjust
						, MAX(h.TurnoverAdjust) as TurnoverAdjust
					FROM bettrans b with (nolock) 
						INNER JOIN CustLimitBetHistory_LIC h WITH(NOLOCK)
							ON h.Transid = b.transid 
					WHERE b.statusID in (0,1) 
						AND h.Matchid = 29 
						AND b.oddsid = 1
						AND b.custid = @custid
					GROUP BY h.transid
				) AS tmp
	
		)

		UPDATE t
		SET AccumPayout = t3.PayoutAdjust 
			, AccumTurnover = t3.TurnoverAdjust
		FROM CustLimitBet_LIC t WITH(ROWLOCK, UPDLOCK)
			CROSS APPLY ( SELECT bettran_cnt FROM cte1 ) AS t1
			CROSS APPLY ( SELECT history_cnt	 FROM cte2 ) AS t2
			CROSS APPLY ( SELECT PayoutAdjust, TurnoverAdjust FROM cte3 ) AS t3
		WHERE t1.bettran_cnt = t2.history_cnt 
			AND t.custid = @custid 
			AND t.matchid = 29
			AND t.EventTypeID = 3
			AND t3.PayoutAdjust IS NOT NULL
			AND (t3.PayoutAdjust <> t.AccumPayout OR t3.TurnoverAdjust <> t.AccumTurnover)

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
