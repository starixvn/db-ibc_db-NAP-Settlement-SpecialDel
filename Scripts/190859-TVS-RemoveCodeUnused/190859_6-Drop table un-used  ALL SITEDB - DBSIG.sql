/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230303@July
	Task: Drop table un-used  [Redmine:#190859]  
	DB: DBSIG-bodb02
	
*/
USE bodb02
GO

IF OBJECT_ID('TicketVoiding_Request','U') IS NOT NULL 
	DROP TABLE TicketVoiding_Request
GO
IF OBJECT_ID('TicketVoiding_RequestDetail','U') IS NOT NULL 
	DROP TABLE TicketVoiding_RequestDetail
GO
IF OBJECT_ID('TicketVoiding_RequestDetailTicket_Single','U') IS NOT NULL 
	DROP TABLE TicketVoiding_RequestDetailTicket_Single
GO
IF OBJECT_ID('TicketVoiding_RequestDetailTicket_SubParlay','U') IS NOT NULL 
	DROP TABLE TicketVoiding_RequestDetailTicket_SubParlay
GO
IF OBJECT_ID('Ticketvoiding_VoidBetAutomation_Service','U') IS NOT NULL 
	DROP TABLE Ticketvoiding_VoidBetAutomation_Service
GO
IF OBJECT_ID('TicketVoiding_VoidedTransaction','U') IS NOT NULL 
	DROP TABLE TicketVoiding_VoidedTransaction
GO
IF OBJECT_ID('TicketVoiding_VoidingHistory','U') IS NOT NULL 
	DROP TABLE TicketVoiding_VoidingHistory
GO
IF OBJECT_ID('TicketVoiding_AutoUnmarkSetting','U') IS NOT NULL 
	DROP TABLE TicketVoiding_AutoUnmarkSetting
GO
IF OBJECT_ID('TicketVoiding_ABWhiteList','U') IS NOT NULL 
	DROP TABLE TicketVoiding_ABWhiteList
GO
IF OBJECT_ID('TicketVoiding_Action','U') IS NOT NULL 
	DROP TABLE TicketVoiding_Action
GO
IF OBJECT_ID('TicketVoiding_IssueType','U') IS NOT NULL 
	DROP TABLE TicketVoiding_IssueType
GO
IF OBJECT_ID('TicketVoiding_SubIssueType','U') IS NOT NULL 
	DROP TABLE TicketVoiding_SubIssueType
GO
IF OBJECT_ID('TicketVoiding_MessageTemplate','U') IS NOT NULL 
	DROP TABLE TicketVoiding_MessageTemplate
GO
IF OBJECT_ID('TicketVoiding_MessageTemplateSetting','U') IS NOT NULL 
	DROP TABLE TicketVoiding_MessageTemplateSetting
GO
IF OBJECT_ID('TicketVoiding_Reason','U') IS NOT NULL 
	DROP TABLE TicketVoiding_Reason
GO
IF OBJECT_ID('TicketVoiding_ReasonTemplate','U') IS NOT NULL 
	DROP TABLE TicketVoiding_ReasonTemplate
GO
IF OBJECT_ID('TicketVoiding_OperatorInfo','U') IS NOT NULL 
	DROP TABLE TicketVoiding_OperatorInfo
GO
IF OBJECT_ID('TicketVoiding_Letstalk','U') IS NOT NULL 
	DROP TABLE TicketVoiding_Letstalk
GO
