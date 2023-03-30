/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230221@July
	Task: Drop column IsSentLetsTalk table Ticketvoiding_VoidBetAutomation_Service  [Redmine:#176998]  
	DB: DBCTG-bodb02
	
*/
USE bodb02
GO

ALTER TABLE Ticketvoiding_VoidBetAutomation_Service DROP COLUMN IsSentLetsTalk;
