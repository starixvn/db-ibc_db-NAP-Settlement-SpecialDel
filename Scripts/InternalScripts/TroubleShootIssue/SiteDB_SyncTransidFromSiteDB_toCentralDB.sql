/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

-- run on sitedb server got issue
USE bodb02
GO

DECLARE @transid VARCHAR(MAX) = '', @TableName VARCHAR(200)

SET @transid = XXX
SET @TableName = XXXX -- bettrans or bettransm
--should define primary key for the temporary tables
CREATE TABLE #Result(
	id [int] IDENTITY (1,1) PRIMARY KEY,
	Transid BIGINT
)

INSERT INTO #Result (Transid)
SELECT f.[value] AS transid
FROM STRING_SPLIT(@transid, ',') f 

------ info for deployer
DECLARE @StartRow INT 
		, @StopRow INT 
		, @MaxRow INT  -- Keep the total row of your data
		, @Threshold INT  -- the number of each batch
		
DECLARE @debug_message VARCHAR(500)
SET @MaxRow = (SELECT MAX(ID) FROM #Result)
SET @Threshold = 2000

IF @Threshold >= @MaxRow
	SET @Threshold = @MaxRow

-- SET for first batch
SELECT @StartRow = 1, @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
BEGIN
		PRINT @StartRow
		PRINT @StopRow
	
	-- YOUR CODE PROCESS FOR DATA FROM @StartRow & @StopRow
		IF @TableName = 'bettrans'
		BEGIN
			UPDATE b
				SET RepUpdateTime = GETDATE()
			FROM bettrans b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN #Result r ON r.Transid = b.TransId
			WHERE ID BETWEEN @StartRow AND @StopRow
		END
		
		ELSE IF @TableName = 'bettransm'
		BEGIN
			UPDATE b
				SET RepUpdateTime = GETDATE()
			FROM bettransm b WITH (ROWLOCK,UPDLOCK)
				INNER JOIN #Result r ON r.Transid = b.TransId
			WHERE ID BETWEEN @StartRow AND @StopRow
		END
		ELSE
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.020' --optional

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

END

DROP TABLE #Result
