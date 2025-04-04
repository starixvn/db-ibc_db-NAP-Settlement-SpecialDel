/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20250402@July
	Task: Manage Request - Add new function and status "Stored" for request [Redmine: #213398]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

ALTER TABLE dbo.TicketVoiding_Request ADD IsStored BIT DEFAULT(0)
GO