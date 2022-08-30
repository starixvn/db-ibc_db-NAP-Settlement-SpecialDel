/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@Max
	Task: Rename column on Ticketvoiding_VoidBetAutomation_Service [Redmine:#175412]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO

CREATE TABLE #tmpResult (Id INT PRIMARY KEY, Isfinished BIT)

DECLARE @tmpResultBatch AS TABLE (Id INT PRIMARY KEY)

INSERT INTO #tmpResult (Id)
SELECT s.Id
FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH (NOLOCK)


DECLARE @debug_message VARCHAR(500)
WHILE (1 = 1)
BEGIN
	
	UPDATE TOP (4000) r
		SET r.Isfinished = 1	
	OUTPUT DELETED.ID INTO @tmpResultBatch (ID)		
	FROM #tmpResult r
	WHERE Isfinished IS NULL
	
	IF @@ROWCOUNT = 0
		BREAK

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
	
	UPDATE s WITH (ROWLOCK, UPDLOCK)
		SET s.VoidingHistoryId = s.VoidingHistory
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service s
		INNER JOIN @tmpResultBatch t ON t.Id = s.Id

	WAITFOR DELAY '00:00:00.050' 
	
	DELETE @tmpResultBatch
		
END

DROP TABLE #tmpResult