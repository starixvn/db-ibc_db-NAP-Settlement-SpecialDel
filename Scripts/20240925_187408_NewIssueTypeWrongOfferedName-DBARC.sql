/*<info serverAlias="DBARC-bodb_Archive" executers="" isFunction="0"></info>*/
/*
	Created: 20241025@July
	Task: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
	DB: DBARC-bodb_Archive
*/
USE bodb_Archive
GO
--Change VARCHAR => NVARCHAR
ALTER TABLE TicketVoiding_RequestDetail_bk ALTER COLUMN TransIds NVARCHAR(MAX);
