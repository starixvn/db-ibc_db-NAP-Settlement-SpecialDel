/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20200518@Max
	Task: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
	DB: DBTXN/bodb02
		
*/
USE bodb02
GO

UPDATE TicketVoiding_Action SET ActionName = 'Auto Void Winning'
WHERE ActionId = 1

SET IDENTITY_INSERT TicketVoiding_Action OFF
INSERT INTO TicketVoiding_Action (ActionId, ActionName)
VALUES (4, 'Auto Void All (Instant)')
	, (5, 'Manual Void')
SET IDENTITY_INSERT TicketVoiding_Action ON	