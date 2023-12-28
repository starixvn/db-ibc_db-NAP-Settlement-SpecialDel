/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20231227@July
	Task: [TVS] Recover Ticket - New Issue Type [Redmine: #196020]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (22, 'Recover Ticket')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName)
VALUES (22, 123, 'Recover Ticket')
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--TicketVoiding_Action
SET IDENTITY_INSERT [dbo].[TicketVoiding_Action] ON
INSERT INTO dbo.TicketVoiding_Action(ActionId, ActionName)
VALUES (11, 'Auto Recover')
SET IDENTITY_INSERT [dbo].[TicketVoiding_Action] OFF

ALTER TABLE [dbo].[Ticketvoiding_VoidBetAutomation_Service]
ADD IsDeletedVoidedTransaction BIT NULL


