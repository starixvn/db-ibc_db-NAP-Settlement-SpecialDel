/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*
	Created: 20241025@July
	Task: [TVS] Add new Advanced Mode for TVS - [Redmine: #212394]
	DB: DBARC-bodb_Archive
*/
USE bodb_Archive
GO
--Change NVARCHAR(300) => NVARCHAR(MAX)
ALTER TABLE TicketVoiding_RequestDetail_bk ALTER COLUMN IssueDetail NVARCHAR(MAX);