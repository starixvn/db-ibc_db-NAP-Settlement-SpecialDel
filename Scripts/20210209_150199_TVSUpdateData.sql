/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210209@Max
	Task: TVS - Letstalk, sent Email and miss data on tables after void when request has more than 3000 tickets - [Redmine: #150199]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

INSERT INTO dbo.TicketVoiding_VoidedTransaction (TransId, MessageId, ReasonId, MatchId, CreatedDate, IssueTypeID, SubIssueTypeID, CustID)
SELECT b.transid, 1134237, 64399, 0	, '2021-02-07 08:11:53.440', 13, 39, b.custid
FROM dbo.zzzbettrans b WITH (NOLOCK)
	OUTER APPLY (
			SELECT v.TransId
			FROM dbo.TicketVoiding_VoidedTransaction v WITH (NOLOCK)
			WHERE v.TransId = b.transid
		)t
WHERE b.VoidingHistoryId = 34943
	AND  t.TransId IS NULL