/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230706@July
	Task: [TVS] Drop 2 table archive   [Redmine:#190859]  
	DB: DBARC-bodb_Archive
	
*/
USE bodb_Archive
GO

IF OBJECT_ID('TicketVoiding_AutoVoidRequest_Queue_bk','U') IS NOT NULL 
	DROP TABLE TicketVoiding_AutoVoidRequest_Queue_bk
GO

IF OBJECT_ID('TicketVoiding_Queue_bk','U') IS NOT NULL 
	DROP TABLE TicketVoiding_Queue_bk
GO
