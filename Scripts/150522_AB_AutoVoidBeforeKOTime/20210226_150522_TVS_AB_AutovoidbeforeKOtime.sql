/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210303@July
	Task: [TVS] Abnormal Bet - Auto void before KO time- [Redmine: #150522]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

 INSERT INTO dbo.TicketVoiding_Action (ActionName) VALUES ('Auto Void All (5m before KO)')
 INSERT INTO dbo.TicketVoiding_Action (ActionName) VALUES ('Auto Void All (10m before KO)')