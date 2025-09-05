/*	
	Created by: 20250905@July
	Task: Update table TicketVoiding_RoutineTasks - [Redmine: ]
	DB: DBSIC/bodb02
*/
--Only sitedb03
USE bodb02
GO
UPDATE  dbo.TicketVoiding_RoutineTasks (ROWLOCK, UPDLOCK) 
SET Status = 2
WHERE  affectedlist like '%5013852%' AND requestid = 565
AND Status <> 2