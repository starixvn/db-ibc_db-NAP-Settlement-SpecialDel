/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210830@July
	Task: TVS - Enhance for Red Card Issue Type - Migrate Data [Redmine: #157097]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

UPDATE rd
SET rd.TransIds = '<r AA="0" PA="0" SA="0" IsMainMatch="true" />'
FROM dbo.TicketVoiding_RequestDetail rd
	INNER JOIN dbo.TicketVoiding_Request r ON rd.requestid = r.requestid 
WHERE r.IssueTypeId = 10