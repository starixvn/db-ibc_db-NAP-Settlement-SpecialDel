/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240924@July
	Task: [TVS] Update script [Redmine: #210152]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_ReasonTemplate
UPDATE r WITH(ROWLOCK, UPDLOCK)
SET r.Sporttype = 0
FROM TicketVoiding_ReasonTemplate r
	INNER JOIN dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) ON r.SubIssueTypeId = s.SubIssueTypeId
WHERE s.IssueTypeId IN (2,4,5,6,7)
