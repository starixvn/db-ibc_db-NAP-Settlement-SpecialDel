/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20200818@Max 
	Task: [TVS] Danger Accept Bets Issue Type - Migrate Old Data [Redmine: #135947]
	DB: DBTXN/bodb02
*/

USE bodb02
GO


CREATE TABLE #TransIds_tmp (RequestId INT, TransIds VARCHAR(MAX), IssueTypeId TINYINT, SubIssueTypeId SMALLINT, MatchId INT)

INSERT INTO #TransIds_tmp (RequestId, TransIds, IssueTypeId, SubIssueTypeId, MatchId)
SELECT r.RequestId, rd.TransIds, r.IssueTypeId, r.SubIssueTypeId, rd.MatchId
FROM TicketVoiding_RequestDetail rd WITH (NOLOCK)
	INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rd.RequestId
WHERE rd.TransIds IS NOT NULL

-------------------------------------------------------------------
CREATE TABLE #TicketVoiding_RequestDetailTicket_Single (RequestId INT, IssueTypeId TINYINT, SubIssueTypeId SMALLINT, MatchId INT, TransId BIGINT)

INSERT INTO #TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, MatchId, TransId)
SELECT t.RequestId, t.IssueTypeId, t.SubIssueTypeId, t.MatchId, tmp.transid
FROM #TransIds_tmp t WITH (NOLOCK) 
	CROSS APPLY (SELECT val AS transid
					FROM dbo.f_SplitString(t.TransIds, ',')
				) AS tmp
OPTION (maxrecursion 0)

-------------------------------------------------------------------
DECLARE @tmpTransIdBatch TABLE (RequestId INT, IssueTypeId TINYINT, SubIssueTypeId SMALLINT, MatchId INT, TransId BIGINT)
WHILE (1=1)
BEGIN
	WAITFOR DELAY '00:00:00.500'
	
	DELETE FROM @tmpTransIdBatch
			
	DELETE TOP (10000) #TicketVoiding_RequestDetailTicket_Single
	OUTPUT	DELETED.RequestId, DELETED.IssueTypeId, DELETED.SubIssueTypeId, DELETED.MatchId, DELETED.TransId
	INTO @tmpTransIdBatch(RequestId, IssueTypeId, SubIssueTypeId, MatchId, TransId)
			
	IF @@ROWCOUNT = 0
		BREAK

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, MatchId, TransId)
	SELECT t.RequestId, t.IssueTypeId, t.SubIssueTypeId, t.MatchId, t.TransId
	FROM @tmpTransIdBatch t
END

DROP TABLE #TicketVoiding_RequestDetailTicket_Single
DROP TABLE #TransIds_tmp

GO