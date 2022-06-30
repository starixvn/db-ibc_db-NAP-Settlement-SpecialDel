/*<info serverAlias="xxx-xxx" executers="" isFunction="0"></info>*/
/*
    Created: xxxx
	Task: xxxx
	DB: xxx-xxx 
*/
USE bodbxxx
GO

--should define primary key for the temporary tables
CREATE TABLE #Result(
	id [int] IDENTITY (1,1) PRIMARY KEY,
	
)

CREATE TABLE #Result_batch(
	id [int] ,
)

INSERT INTO #Result (id)
SELECT XXXX

------ info for deployer
DECLARE @StartRow INT = 1
		, @StopRow INT 
		, @MaxRow INT = 1 -- Keep the total row of your data
		, @Threshold INT = 20000 -- the number of each batch
		
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
		OUTPUT DELETED.ID
		INTO #Result_batch (ID)		
		FROM #Result R
		WHERE ID BETWEEN @StartRow AND @StopRow

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT

		-- YOUR CODE PROCESS FOR DATA FROM @StartRow & @StopRow
		
		IF @StopRow = @MaxRow BREAK
	

		WAITFOR DELAY '00:00:00.100' --optional
		TRUNCATE TABLE #Result_batch

		SET @StartRow = @StopRow + 1
		SET @StopRow = 1 + @StopRow + @Threshold
		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

END

DROP TABLE #Result
DROP TABLE #Result_batch