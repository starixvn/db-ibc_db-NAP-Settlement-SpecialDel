/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20250402@July
	Task: Archived Request Function [Redmine: #213398]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

ALTER TABLE dbo.TicketVoiding_Request ADD IsArchived BIT DEFAULT(0)
GO


