/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Drop column un-used  [Redmine:#180625]  
	DB: DBARC.bodb_Archive
		   
*/
USE bodb_Archive
GO

ALTER TABLE TicketVoiding_Request_bk DROP COLUMN SubIssueTypeId 
GO
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN IsCheckedHomeTeam
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN IsCheckedAwayTeam
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN IsFilterByTransTime
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN FilterFromBetId
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN FilterToBetId
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN MinSingleTransId
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN MaxSingleTransId
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN MinMainParlayTransId
ALTER TABLE TicketVoiding_RequestDetail_bk DROP COLUMN MaxMainParlayTransId
GO