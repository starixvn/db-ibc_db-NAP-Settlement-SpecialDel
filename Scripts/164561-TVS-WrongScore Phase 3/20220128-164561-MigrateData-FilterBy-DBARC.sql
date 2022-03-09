/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220128@Max
	Task: TVS - Wrong Score Enhancement - Phase 3 - [Redmine: #164561]
	DB: DBARC-bodb_Archive
*/


USE bodb_Archive
GO

CREATE TABLE #tmpResult (Id INT PRIMARY KEY, Isfinished BIT)

DECLARE @tmpResultBatch AS TABLE (Id INT PRIMARY KEY)

INSERT INTO #tmpResult (Id)
SELECT rd.Id
FROM TicketVoiding_RequestDetail_bk rd WITH (NOLOCK)
	INNER JOIN TicketVoiding_Request_bk r WITH (NOLOCK) ON r.RequestId = rd.RequestId AND r.IssueTypeId = 3
WHERE rd.FilterBy IS NULL

DECLARE @debug_message VARCHAR(500)
WHILE (1 = 1)
BEGIN
	
	UPDATE TOP (2000) r
		SET r.Isfinished = 1	
	OUTPUT DELETED.ID INTO @tmpResultBatch (ID)		
	FROM #tmpResult r
	WHERE Isfinished IS NULL
	
	IF @@ROWCOUNT = 0
		BREAK

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
	
	UPDATE rd WITH (ROWLOCK, UPDLOCK)
		SET rd.FilterBy = 1
	FROM TicketVoiding_RequestDetail_bk rd
		INNER JOIN @tmpResultBatch t ON t.Id = rd.Id

	WAITFOR DELAY '00:00:00.050' 
	
	DELETE @tmpResultBatch
		
END

DROP TABLE #tmpResult








