/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20200825@Max 
	Task: [TVS] HotFix - Danger Accept [Redmine: #140164]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

CREATE TABLE #Request_tmp (RequestId INT, IssueTypeId TINYINT, SubIssueTypeId SMALLINT)
INSERT INTO #Request_tmp (RequestId, IssueTypeId, SubIssueTypeId)
SELECT r.RequestId, r.IssueTypeId, r.SubIssueTypeId
FROM TicketVoiding_Request r WITH (NOLOCK)
	OUTER APPLY (
				SELECT TOP 1 RequestId
				FROM TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
				WHERE RequestId = r.RequestId
				UNION ALL
				SELECT TOP 1 RequestId
				FROM TicketVoiding_RequestDetailTicket_SubParlay WITH (NOLOCK)
				WHERE RequestId = r.RequestId
		) t
WHERE t.RequestId IS NULL
	AND r.CreatedDate >= '2020-08-19'

INSERT INTO TicketVoiding_RequestDetailTicket_Single (RequestId, MatchId, IssueTypeId, SubIssueTypeId, TransId)
SELECT t.RequestId, b.matchid, t.IssueTypeId, t.SubIssueTypeId, b.transid
FROM zzzbettrans b WITH (NOLOCK)
	INNER JOIN TicketVoiding_VoidingHistory vh WITH (NOLOCK) on vh.VoidingHistoryId = b.VoidingHistoryId
	INNER JOIN #Request_tmp t on t.RequestId = vh.RequestId
	OUTER APPLY (
			SELECT TOP 1 transid
			FROM zzzbettransm WITH (NOLOCK)
			WHERE transid = b.transid
		) bm
WHERE bm.transid IS NULL

INSERT INTO TicketVoiding_RequestDetailTicket_SubParlay(RequestId, MatchId, IssueTypeId, SubIssueTypeId, TransId)
SELECT t.RequestId, b.matchid, t.IssueTypeId, t.SubIssueTypeId, b.transid
FROM zzzbettransm b WITH (NOLOCK)
	INNER JOIN TicketVoiding_VoidingHistory vh WITH (NOLOCK) on vh.VoidingHistoryId = b.VoidingHistoryId
	INNER JOIN #Request_tmp t on t.RequestId = vh.RequestId 

DROP TABLE #Request_tmp
	


