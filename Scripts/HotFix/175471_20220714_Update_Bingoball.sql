/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20220714@Louisa
	Task: Update Bingoball.IsDelete = 0 [Redmine:#175471]
	DB: DBPRO-bodb02
*/
USE BODB02
GO

--should define primary key for the temporary tables
CREATE TABLE #Result(
	id [int] IDENTITY (1,1) PRIMARY KEY,
	Matchid	int,
	Seq	tinyint
	
)

CREATE TABLE #Result_batch(
	Matchid	int,
	Seq	tinyint
)

INSERT INTO #Result ( Matchid, Seq)
SELECT matchid,seq
FROM bingoBall WITH (NOLOCK)
WHERE IsDeleted = 1

------ info for deployer
DECLARE @StartRow INT = 1
		, @StopRow INT 
		, @MaxRow INT = 1 -- Keep the total row of your data
		, @Threshold INT = 5000 -- the number of each batch
		
DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(ID) FROM #Result)

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SET @StopRow = @Threshold

WHILE (1 = 1)
BEGIN
	
		PRINT @StartRow
		PRINT @StopRow
		
		DELETE R
		OUTPUT DELETED.Matchid, DELETED.Seq
		INTO #Result_batch (Matchid,Seq)		
		FROM #Result R
		WHERE ID BETWEEN @StartRow AND @StopRow

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		-- YOUR CODE PROCESS FOR DATA FROM @StartRow & @StopRow
		UPDATE b
			SET IsDeleted = 0, UpdateTime = GETDATE()
		FROM bingoBall b WITH (ROWLOCK)
			INNER JOIN #Result_batch r ON b.Matchid = r.Matchid AND b.Seq = r.Seq
		
		IF @StopRow = @MaxRow BREAK
	
		WAITFOR DELAY '00:00:00.100' --optional
		
		TRUNCATE TABLE #Result_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

END

DROP TABLE #Result
DROP TABLE #Result_batch