/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220128@Max
	Task: TVS - Wrong Score Enhancement - Phase 3 - [Redmine: #164561]
	DB: DBARC-bodb_Archive
*/


USE bodb_Archive
GO

CREATE TABLE #tmpResult (Id INT PRIMARY KEY, IssueTypeId INT, Isfinished BIT)

DECLARE @tmpResultBatch AS TABLE (Id INT PRIMARY KEY, IssueTypeId INT)

INSERT INTO #tmpResult (Id, IssueTypeId)
SELECT rd.Id, r.IssueTypeId
FROM TicketVoiding_RequestDetail_bk rd WITH (NOLOCK)
	INNER JOIN TicketVoiding_Request_bk r WITH (NOLOCK) ON r.RequestId = rd.RequestId AND r.IssueTypeId IN (1,3,4,5,10)
WHERE rd.IssueDetail <> ''

DECLARE @debug_message VARCHAR(500)
WHILE (1 = 1)
BEGIN
	
	UPDATE TOP (2000) r
		SET r.Isfinished = 1	
	OUTPUT DELETED.ID, DELETED.IssueTypeId INTO @tmpResultBatch (ID, IssueTypeId)		
	FROM #tmpResult r
	WHERE Isfinished IS NULL
	
	IF @@ROWCOUNT = 0
		BREAK

	SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
	RAISERROR (@debug_message, 0, 1) WITH NOWAIT
	
	UPDATE rd WITH (ROWLOCK, UPDLOCK)
		SET rd.IssueDetail = CASE WHEN t.IssueTypeId = 3 THEN 'Live:;Act:' + rd.IssueDetail ELSE 'Live:'+ rd.IssueDetail + ';Act:' END
	FROM TicketVoiding_RequestDetail_bk rd
		INNER JOIN @tmpResultBatch t ON t.Id = rd.Id

	WAITFOR DELAY '00:00:00.050' 
	
	DELETE @tmpResultBatch
		
END

DROP TABLE #tmpResult








