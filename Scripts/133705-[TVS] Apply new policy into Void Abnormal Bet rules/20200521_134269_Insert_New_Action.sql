/*
	Created: 20200312@Max
	Task: Support Quarter X, Y, Z on Auto Unmark Page [Redmine: #130205]
	DB: DBTRANS/bodb02
		
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