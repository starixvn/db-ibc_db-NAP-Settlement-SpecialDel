/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20250718@Lani
	Task: [TVS] Technical Error - Update the void reason [Redmine: #233634]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

UPDATE rt
SET rt.ReasonEnglish = 'Match Issue'
   ,rt.ReasonChineseSimplified = N'赛事有误'
FROM TicketVoiding_ReasonTemplate AS rt WITH (UPDLOCK, ROWLOCK)
INNER JOIN TicketVoiding_SubIssueType AS s WITH (NOLOCK) ON rt.SubIssueTypeId = s.SubIssueTypeId
INNER JOIN TicketVoiding_IssueType AS i WITH (NOLOCK) ON i.IssueTypeId = s.IssueTypeId
WHERE i.IssueTypeName = 'Technical Error'
