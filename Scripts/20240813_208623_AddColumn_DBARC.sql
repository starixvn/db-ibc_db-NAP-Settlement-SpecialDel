/*<info serverAlias="DBARC-bodb_archive" executers="" isFunction="0"></info>*/
/*
	Created: 20240813@Max 
	Task: [TVS] Manage Request - Enhancements - [Redmine: #208623]
	DB: DBARC/bodb_archive
*/
USE bodb_archive
GO

--TicketVoiding_RequestDetail
ALTER TABLE dbo.TicketVoiding_Request_bk ADD BriefInfoNote NVARCHAR(MAX)
GO



