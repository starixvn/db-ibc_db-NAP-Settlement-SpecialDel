/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20231130@Max
	Task: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
	DB: DBCTG/bodb02
		
*/
USE bodb02
GO

SET IDENTITY_INSERT TicketVoiding_Action ON
INSERT INTO TicketVoiding_Action (ActionId, ActionName)
VALUES (10, 'Auto Void (Instant with Policy)')
SET IDENTITY_INSERT TicketVoiding_Action OFF	
