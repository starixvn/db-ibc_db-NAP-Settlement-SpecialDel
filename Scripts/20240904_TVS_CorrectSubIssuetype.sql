/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240904@Max 
	Task: correct subissuetype for wrong KO time request - [Redmine: #00000]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

UPDATE rd WITH (ROWLOCK, UPDLOCK)
SET rd.SubIssueTypeId = 14
FROM dbo.TicketVoiding_RequestDetail rd
WHERE rd.RequestId IN (119886, 119887)



