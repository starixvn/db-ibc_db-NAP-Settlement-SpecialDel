/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: Max
	Task : [TVS] Insert duplicate voided transaction
	DB: DBCTG-bodb02

	Revisions:
		- 20240409@Max: Create script [Redmine: #203614]

	Note:
*/

DECLARE @tmp_TransId TABLE (TransId BIGINT)
DECLARE @tmp_delete_Id TABLE (Id BIGINT)

INSERT INTO @tmp_TransId (TransId)
SELECT v.transid
FROM TicketVoiding_VoidedTransaction v with (nolock)
WHERE v.MatchId <> 0
GROUP BY transid, VoidingHistoryId, matchid, createddate, IssueTypeID
HAVING COUNT(transid) > 1

SELECT v.Id
FROM @tmp_TransId t
INNER JOIN dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK) ON t.TransId = v.TransId

;WITH CTE(
	Id, 
    DuplicateCount)
AS (
	SELECT v.Id, 
           ROW_NUMBER() OVER(PARTITION BY t.TransId ORDER BY t.TransId) AS DuplicateCount
    FROM @tmp_TransId t
		INNER JOIN dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK) ON t.TransId = v.TransId
)
INSERT INTO @tmp_delete_Id (Id)
SELECT Id FROM CTE
WHERE DuplicateCount > 1;

DELETE v
FROM dbo.TicketVoiding_VoidedTransaction v
	INNER JOIN @tmp_delete_Id t ON t.Id = v.Id