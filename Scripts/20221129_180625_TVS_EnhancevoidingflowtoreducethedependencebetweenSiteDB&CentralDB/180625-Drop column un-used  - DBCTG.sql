/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Drop column un-used  [Redmine:#180625]  
	DB: DBCTG-bodb02
	
	Note: Replication DBTrans_API_Data
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_Request DROP COLUMN SubIssueTypeId 
GO
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN IsCheckedHomeTeam
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN IsCheckedAwayTeam
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN IsFilterByTransTime
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN FilterFromBetId
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN FilterToBetId
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MinSingleTransId
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MaxSingleTransId
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MinMainParlayTransId
ALTER TABLE TicketVoiding_RequestDetail DROP COLUMN MaxMainParlayTransId
GO