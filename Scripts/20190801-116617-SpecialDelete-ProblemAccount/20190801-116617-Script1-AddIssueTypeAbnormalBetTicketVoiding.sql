/*
	Script 1
	Created by: Raymond
	Date: 20190801
	Task: Add Issue Type for Abnormal Bet #116617
	DB: DBTXN/bodb02
*/
USE [bodb02];
GO

-- Insert IssueType 11
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO [dbo].[TicketVoiding_IssueType] (
	IssueTypeId
	,IssueTypeName
)
VALUES (11, 'Abnormal Bet');
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO [dbo].[TicketVoiding_SubIssueType] (
	[SubIssueTypeId]
  ,[IssueTypeId]
  ,[SubIssueTypeName]
) 
VALUES (27, 11, 'Abnormal'),
	(28, 11, 'Group Betting'),
	(29, 11, 'Hedging'),
	(30, 11, 'Arbitrage'),
	(31, 11, 'Fixed Game');
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--
INSERT INTO [dbo].[TicketVoiding_MessageTemplateSetting] (
	[TemplateId]
  ,[Sporttype]
  ,[SubIssueTypeId]  
)
VALUES (34, NULL, 27),
	  (34, NULL, 28),
	  (34, NULL, 29),
	  (34, NULL, 30),
	  (34, NULL, 31);

