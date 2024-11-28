/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241122@July
	Task: Drop column un-used  [Redmine:#212928]  
	DB: DBCTG-bodb02 & Replicated Server for DBTrans_Sync_DB06
*/
USE bodb02
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MinWinlostdate' AND Object_ID = Object_ID(N'TicketVoiding_VoidingHistory'))
BEGIN
    ALTER TABLE TicketVoiding_VoidingHistory DROP COLUMN MinWinlostdate 
END

GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MaxWinlostdate' AND Object_ID = Object_ID(N'TicketVoiding_VoidingHistory'))
BEGIN
    ALTER TABLE TicketVoiding_VoidingHistory DROP COLUMN MaxWinlostdate
END
