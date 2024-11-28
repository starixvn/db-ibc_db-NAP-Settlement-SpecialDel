/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241122@July
	Task: Drop column un-used  [Redmine:#212928]  
	DB: DBARC-bodb_Archive
*/
USE bodb_Archive
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MinWinlostdate' AND Object_ID = Object_ID(N'TicketVoiding_VoidingHistory_bk'))
BEGIN
    ALTER TABLE TicketVoiding_VoidingHistory_bk DROP COLUMN MinWinlostdate 
END

GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MaxWinlostdate' AND Object_ID = Object_ID(N'TicketVoiding_VoidingHistory_bk'))
BEGIN
    ALTER TABLE TicketVoiding_VoidingHistory_bk DROP COLUMN MaxWinlostdate
END
