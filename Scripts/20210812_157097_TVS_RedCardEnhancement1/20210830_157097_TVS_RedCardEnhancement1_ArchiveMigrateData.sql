/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210830@July
	Task: TVS - Enhance for Red Card Issue Type - Archive Migrate Data - [Redmine: #157097]
	DB: DBARC/bodb_Archive
*/
USE bodb_Archive
GO

UPDATE rd
SET rd.TransIds = '<r AA="0" PA="0" SA="0" IsMainMatch="true" />'
FROM dbo.TicketVoiding_RequestDetail_bk rd
	INNER JOIN dbo.TicketVoiding_Request_bk r ON rd.requestid = r.requestid 
WHERE r.IssueTypeId = 10