/*<info serverAlias="DBCTG-bodb02, DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230303@July
	Task: Drop table un-used  [Redmine:#190859]  
	DB: DBCTG-bodb02, DBSIG-bodb02
	
*/
USE bodb02
GO

IF OBJECT_ID('TicketVoiding_Void_Service','U') IS NOT NULL 
	DROP TABLE TicketVoiding_Void_Service
GO
IF OBJECT_ID('TicketVoiding_RequestDetail_MixParlay','U') IS NOT NULL 
	DROP TABLE TicketVoiding_RequestDetail_MixParlay
GO
IF OBJECT_ID('TicketVoiding_AutoMarkService_AutoSetting','U') IS NOT NULL 
	DROP TABLE TicketVoiding_AutoMarkService_AutoSetting
GO
IF OBJECT_ID('TicketVoiding_AutoVoidRequest_Queue','U') IS NOT NULL 
	DROP TABLE TicketVoiding_AutoVoidRequest_Queue
GO
