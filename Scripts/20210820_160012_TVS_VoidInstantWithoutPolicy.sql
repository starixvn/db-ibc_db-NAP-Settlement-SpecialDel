/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/  
/*
	Created: 20210820@July
	DB: DBTXN.bodb02
	Task: Add new status Void Instant without any policy [Redmine:#160012]
	
*/
USE [bodb02]
GO

SET IDENTITY_INSERT  TicketVoiding_Action ON
INSERT INTO TicketVoiding_Action (ActionId, ActionName) VALUES (8, N'Auto Void All (Instant w/o Policy)')
SET IDENTITY_INSERT  TicketVoiding_Action OFF	
