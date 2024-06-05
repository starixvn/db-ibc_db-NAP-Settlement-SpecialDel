/*<info serverAlias="DBSID-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240604@Louisa
	Task: Correct CustLimitBet_LIC when exists running ticket [Redmine:#206061]
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
FROM CustLimitBet_LIC c WITH(NOLOCK)
	CROSS APPLY (SELECT TOP 1 1 valid FROM bettrans b WITH (NOLOCK) WHERE custid = c.CustID and oddsid = 99 and matchid = 29 and ruben = 0 ) AS t
WHERE matchid = 29 
	AND c.AccumPayout < 0
	AND c.EventTypeID = 4

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
		;WITH cte1 AS
		(
			SELECT b.custid, COUNT(1) AS bettran_cnt
			FROM bettrans b WITH(NOLOCK)
				INNER JOIN #Temp_CustID c on c.CustID = b.CustID
			WHERE c.ID BETWEEN @StartRow AND @StopRow
				AND  b.statusID in (0,1) 
				AND b.Matchid = 29
				AND b.oddsid = 99
			GROUP BY b.custid
		)
		, cte2 AS
		(
			SELECT h.custid, COUNT(distinct h.transid) as history_cnt
			FROM CustLimitBetHistory_LIC h with (nolock)
				INNER JOIN bettrans b WITH(NOLOCK)
					ON h.Transid = b.transid 
						AND b.matchid = 29
				INNER JOIN #Temp_CustID c ON c.CustID = h.CustID
			WHERE  c.ID BETWEEN @StartRow AND @StopRow
				AND h.matchid = 29
				AND b.oddsid = 99
				AND b.statusID in (0,1)
				AND h.EventTypeID = 4
			GROUP BY h.CustID

		)
		, cte3 AS
		(
			SELECT tmp.custid, SUM(PayoutAdjust) as PayoutAdjust, SUM(TurnoverAdjust) as TurnoverAdjust
			FROM (
					SELECT h.CustID, h.transid
						, MAX(h.PayoutAdjust) as PayoutAdjust
						, MAX(h.TurnoverAdjust) as TurnoverAdjust
					FROM bettrans b with (nolock) 
						INNER JOIN CustLimitBetHistory_LIC h WITH(NOLOCK)
							ON h.Transid = b.transid 
						INNER JOIN #Temp_CustID c ON c.CustID = h.CustID
					WHERE c.ID BETWEEN @StartRow AND @StopRow
						AND b.statusID in (0,1) 
						AND h.Matchid = 29 
						AND b.oddsid = 99
						AND h.EventTypeID = 4
					GROUP BY h.transid, h.custid
				) AS tmp
			GROUP BY tmp.CustID	
	
		)

		UPDATE t
		SET AccumPayout = t3.PayoutAdjust 
			, AccumTurnover = t3.TurnoverAdjust
		FROM CustLimitBet_LIC t WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #Temp_CustID c ON c.CustID = t.CustID
			CROSS APPLY ( SELECT bettran_cnt FROM cte1 t1 WHERE t1.custid = t.CustID ) AS t1
			CROSS APPLY ( SELECT history_cnt	 FROM cte2 t2 WHERE t2.CustID = t.CustID ) AS t2
			CROSS APPLY ( SELECT PayoutAdjust, TurnoverAdjust FROM cte3 t3 WHERE t3.CustID = t.CustID) AS t3
		WHERE c.ID BETWEEN @StartRow AND @StopRow
			AND t1.bettran_cnt = t2.history_cnt 
			AND t.matchid = 29
			AND t.EventTypeID = 4
			AND t3.PayoutAdjust IS NOT NULL
			AND (t3.PayoutAdjust <> t.AccumPayout OR t3.TurnoverAdjust <> t.AccumTurnover)

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
