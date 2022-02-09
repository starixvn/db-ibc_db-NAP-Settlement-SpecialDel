/*<info serverAlias="xxx-xxx" executers="" isFunction="0"></info>*/
/*
    Created: xxxx
	Task: xxxx
	DB: xxx-xxx 
*/
USE bodbxxx
GO


CREATE TABLE #Result(
	id [int] ,
	Isfinished BIT
)

CREATE TABLE #Result_batch(
	id [int] ,
)

INSERT INTO #Result (id)
SELECT XXXX

------ info for deployer

DECLARE @debug_message VARCHAR(500)

WHILE (1 = 1)
BEGIN
	
	UPDATE TOP (1000) R
		SET Isfinished = 1	
	OUTPUT DELETED.ID
	INTO #Result_batch (ID)		
	FROM #Result R
	WHERE Isfinished IS NULL
	
	IF @@ROWCOUNT = 0
		BREAK

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
	
	-- YOUR CODE HERE to process each batch
	
	TRUNCATE TABLE #Result_batch
		
END

DROP TABLE #Result
DROP TABLE #Result_batch