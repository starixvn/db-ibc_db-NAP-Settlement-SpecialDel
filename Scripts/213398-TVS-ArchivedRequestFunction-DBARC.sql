/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*
	Created: 20250402@July
	Task: Archived Request Function [Redmine: #213398]
	DB: DBARC/bodb_Archive
*/
USE bodb_Archive
GO

ALTER TABLE dbo.TicketVoiding_Request_bk ADD IsArchived BIT DEFAULT(0)
GO

