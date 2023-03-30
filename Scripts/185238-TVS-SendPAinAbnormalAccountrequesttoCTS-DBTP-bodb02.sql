/*<info serverAlias="DBTP-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230324@July
	Task: [TVS] Send problem customer in Abnormal Account request to CTS - [Redmine: #185238]
	DB: DBTP-bodb02
*/

USE bodb02
GO

UPDATE vt WITH(ROWLOCK, UPDLOCK) 
SET vt.MatchId = b.matchid
FROM dbo.TicketVoiding_VoidedTransaction vt 
	   CROSS APPLY (
			SELECT b.matchid
			FROM dbo.bettrans b WITH (NOLOCK)
			WHERE vt.TransId = b.TransId AND vt.CustId = b.CustId
		)b
WHERE vt.IssueTypeID IN (11,13) AND vt.MatchId = 0


UPDATE vt WITH(ROWLOCK, UPDLOCK) 
SET vt.MatchId = b14.matchid
FROM dbo.TicketVoiding_VoidedTransaction vt   
		CROSS APPLY (
			SELECT b14.matchid
			FROM dbo.bettrans14 b14 WITH (NOLOCK)
			WHERE vt.TransId = b14.TransId AND vt.CustId = b14.CustId
		)b14
WHERE vt.IssueTypeID IN (11,13) AND vt.MatchId = 0

