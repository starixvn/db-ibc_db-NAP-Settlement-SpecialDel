/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250527@Helen
	Task: Alpha - Potential Winning Limit/Threshold [Redmine: #226060]
	DB:DBSIC-bodb02
*/
USE bodb02
GO

DECLARE @maxTransid BIGINT, @maxRowID BIGINT
SET @maxTransid = (SELECT MAX(transid) FROM bettrans b WITH(NOLOCK))

SELECT @maxTransid as max_Transid
	, GETDATE() AS startTime
	
--should define primary key for the temporary tables
CREATE TABLE #Result(
	id [int] IDENTITY (1,1) PRIMARY KEY,
	custid INT
)

CREATE TABLE #tmp_batch (custid INT)

INSERT INTO #Result (custid)
SELECT DISTINCT custid
FROM bettrans b WITH (NOLOCK)
WHERE currency = 20 AND transid <= @maxTransid
	
------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch

DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(ID) FROM #Result)
SET @Threshold = 1000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

SET @maxRowID = (SELECT MAX(rowID) FROM balancetrigger WITH (NOLOCK))
SELECT @maxRowID AS maxRowID_balancetrigger -- use this one to update new flag in systemsettings

WHILE (@MaxRow IS NOT NULL)
BEGIN
		PRINT @StartRow
		PRINT @StopRow
		TRUNCATE TABLE #tmp_batch

		-- YOUR CODE TO PROCESS DATA FROM @StartRow & @StopRow
		INSERT INTO #tmp_batch (custid)
		SELECT custid
		FROM #Result
		WHERE ID BETWEEN @StartRow AND @StopRow

		UPDATE c
			SET AccumToWin = t.ToWin, AccumWinLoss = 0, RepUpdateTime = dbo.f_GetDateTime2()

		OUTPUT deleted.CustID,deleted.Sporttype, deleted.Bettype,inserted.AccumToWin - deleted.AccumToWin, inserted.AccumWinLoss - deleted.AccumWinLoss, 100 AS ActionType, dbo.f_GetDateTime2()
		INTO CustWinLimitBet_History (custid, Sporttype, Bettype, AdjToWin, AdjWinLoss, ActionType,RepUpdateTime)
		FROM CustWinLimitBet c WITH (ROWLOCK,UPDLOCK)
			INNER JOIN #tmp_batch R ON c.custid = r.custid
			CROSS APPLY (SELECT SUM(ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake) AS ToWin
						FROM bettrans b WITH (NOLOCK)
							CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK) 
										WHERE m.bettype = b.bettype 
										AND m.SportType < 99
								) AS chk
						WHERE b.custid = r.CustID AND b.statusID IN (0,1) AND b.bettype NOT IN (29,38)
							AND b.TransId <= @maxTransid
						GROUP BY b.custid
						) AS t
		--for debug if need
		--SELECT @@ROWCOUNT AS 'Update'

		INSERT INTO  CustWinLimitBet (CustID,Sporttype, Bettype, AccumToWin, AccumWinLoss, CreatedDate,RepUpdateTime)
			OUTPUT inserted.CustID, inserted.Sporttype, inserted.Bettype, inserted.AccumToWin, inserted.AccumWinLoss,100, dbo.f_GetDateTime2() 
			INTO CustWinLimitBet_History (custid, Sporttype, Bettype, AdjToWin, AdjWinLoss, ActionType,RepUpdateTime) 
		SELECT r.custid, 0, 0, t.ToWin, 0, GETDATE(), dbo.f_GetDateTime2()
		FROM #tmp_batch r  
			CROSS APPLY (SELECT SUM(ISNULL(CAST(ISNULL(b.ExtraInfo,'') AS XML).value('(/p1/@pa)[1]', 'MONEY'),0) - b.actual_stake) AS ToWin
						FROM bettrans b WITH (NOLOCK)
							CROSS APPLY (SELECT TOP (1) 1 AS isValid FROM SportBettypeMatrix m WITH (NOLOCK) 
										WHERE m.bettype = b.bettype 
										AND m.SportType < 99
								) AS chk
						WHERE b.custid = r.CustID AND b.statusID IN (0,1) AND b.bettype NOT IN (29,38)
							AND b.TransId <= @maxTransid
						GROUP BY b.custid) AS t
		WHERE NOT EXISTS (SELECT TOP (1) 1 FROM CustWinLimitBet bt WITH (NOLOCK) WHERE bt.CustID = r.custid)

		-- insert action reset for customer that all tickets already settled
		INSERT INTO CustWinLimitBet_History (custid, Sporttype, Bettype, AdjToWin, AdjWinLoss, ActionType,RepUpdateTime)
		SELECT c.custid, 0, 0, 0, 0, 100, dbo.f_GetDateTime2()
		FROM #tmp_batch c 
			OUTER APPLY (SELECT TOP (1) 1 isRunning FROM bettrans b WITH (NOLOCK) WHERE b.custid = c.CustID AND b.statusID IN (0,1)) AS t
		WHERE t.isRunning IS NULL

		--for debug if need
		--SELECT @@ROWCOUNT as 'Insert'

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.100' --optional

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

END

/*
DROP TABLE #Result
DROP TABLE #tmp_batch
*/

