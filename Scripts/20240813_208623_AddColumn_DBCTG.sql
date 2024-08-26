/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240813@Max 
	Task: [TVS] Manage Request - Enhancements - [Redmine: #208623]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_RequestDetail
ALTER TABLE dbo.TicketVoiding_Request ADD BriefInfoNote NVARCHAR(MAX)
GO



