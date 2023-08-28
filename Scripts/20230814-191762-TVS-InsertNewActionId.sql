/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20230814@Max
	Task: [TVS] Reduced Over - Update rule for action "auto void" [Redmine: #191762]
	DB: DBCTG/bodb02
		
*/
USE bodb02
GO

SET IDENTITY_INSERT TicketVoiding_Action OFF
INSERT INTO TicketVoiding_Action (ActionId, ActionName)
VALUES (9, 'Auto Void All (Result keyed)')
SET IDENTITY_INSERT TicketVoiding_Action ON	