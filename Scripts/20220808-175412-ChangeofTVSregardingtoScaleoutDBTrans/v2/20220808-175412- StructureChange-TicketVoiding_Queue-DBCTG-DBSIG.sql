/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@Max
	Task: Structure change - ONLY FOR SIT [Redmine:#175412]  
	DB: DBCTG-bodb02,DBSIG-bodb02
		   
*/
USE bodb02
GO

ALTER TABLE [TicketVoiding_Queue] ADD IssueTypeId TINYINT
GO

