/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Drop table un-used  [Redmine:#180625]  
	DB: DBSIG.bodb02
		   
*/
USE bodb02
GO
DROP TABLE dbo.TicketVoiding_Request
DROP TABLE dbo.TicketVoiding_RequestDetail
DROP TABLE dbo.TicketVoiding_RequestDetailTicket_Single
DROP TABLE dbo.TicketVoiding_RequestDetailTicket_SubParlay
DROP TABLE dbo.TicketVoiding_AutoUnmarkSetting 
DROP TABLE dbo.TicketVoiding_AutoMarkService_AutoSetting
