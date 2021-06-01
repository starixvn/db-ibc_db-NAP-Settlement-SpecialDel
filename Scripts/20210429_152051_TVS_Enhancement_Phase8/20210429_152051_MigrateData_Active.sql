/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210429@July
	Task: TVS - Enhancement- Phase 8 - [Redmine: #152051]
	DB: DBTXN-bodb02
*/
USE bodb02

GO

UPDATE r
SET r.SubIssueTypeId =  CASE
							WHEN r.SubIssueTypeId = 1 AND ISNULL(rd.IsCheckedHomeTeam,0) = 1 THEN 55  --Goal - Home
							WHEN r.SubIssueTypeId = 1 AND ISNULL(rd.IsCheckedAwayTeam,0) = 1 THEN 56  --Goal - Away
							WHEN r.SubIssueTypeId = 2 AND ISNULL(rd.IsCheckedHomeTeam,0) = 1 THEN 68  --Main Corner - Home
							WHEN r.SubIssueTypeId = 2 AND ISNULL(rd.IsCheckedAwayTeam,0) = 1 THEN 69  --Main Corner - Away
							ELSE r.SubIssueTypeId
						END
FROM dbo.TicketVoiding_Request r WITH(ROWLOCK, UPDLOCK)
	INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON r.RequestId = rd.RequestId
WHERE r.IssueTypeId = 1
	AND r.SubIssueTypeId IN (1,2)
	AND (ISNULL(rd.IsCheckedHomeTeam,0)= 1 OR ISNULL(rd.IsCheckedAwayTeam,0)= 1 )