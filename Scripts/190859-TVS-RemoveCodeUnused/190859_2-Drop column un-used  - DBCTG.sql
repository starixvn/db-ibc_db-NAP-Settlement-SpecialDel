/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Drop column un-used  [Redmine:#180625]  
	DB: DBCTG-bodb02
	
	Note: Replication DBTrans_API_Data
*/
USE bodb02
GO

IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'SubIssueTypeId' AND Object_ID = Object_ID(N'TicketVoiding_Request'))
BEGIN
    ALTER TABLE TicketVoiding_Request DROP COLUMN SubIssueTypeId 
END

GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'IsCheckedHomeTeam' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
    ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN IsCheckedHomeTeam
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'IsCheckedAwayTeam' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN IsCheckedAwayTeam
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'IsFilterByTransTime' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN IsFilterByTransTime
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'FilterFromBetId' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN FilterFromBetId
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'FilterToBetId' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN FilterToBetId
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MinSingleTransId' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MinSingleTransId
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MaxSingleTransId' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MaxSingleTransId
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MinMainParlayTransId' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MinMainParlayTransId
END
GO
IF EXISTS(SELECT 1 FROM sys.columns WHERE Name = N'MaxMainParlayTransId' AND Object_ID = Object_ID(N'TicketVoiding_RequestDetail'))
BEGIN
	ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MaxMainParlayTransId
END
GO


