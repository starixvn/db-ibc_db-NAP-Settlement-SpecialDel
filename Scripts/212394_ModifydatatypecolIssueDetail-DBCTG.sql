/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20241025@July
	Task: [TVS] Add new Advanced Mode for TVS - [Redmine: #212394]
	DB: DBCTG/bodb02
*/
USE bodb02
GO
--Change NVARCHAR(300) => NVARCHAR(MAX)
ALTER TABLE TicketVoiding_RequestDetail ALTER COLUMN IssueDetail NVARCHAR(MAX);
