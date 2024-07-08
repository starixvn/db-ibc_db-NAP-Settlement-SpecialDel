/*<info serverAlias="DBARC-bodb_archive" executers="" isFunction="0"></info>*/
/*
	Created: 20240516@Max 
	Task: [TVS] Wrong Market Offered issue type - [Redmine: #197051]
	DB: DBARC-DBARC-bodb_archive
*/
USE bodb_archive
GO

--TicketVoiding_RequestDetail_bk
ALTER TABLE dbo.TicketVoiding_RequestDetail_bk ADD AdvancedExtraInfo VARCHAR(MAX)
GO



