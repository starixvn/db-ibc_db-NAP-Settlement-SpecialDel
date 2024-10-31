/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240916@Max
	Task: [TVS] Support void wrong odds for Sportsbook [Redmine: #186029]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (25, 'Wrong Odds (Sportsbook)')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName)
VALUES (25, 125, 'Wrong Odds (Sportsbook)')
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 125, 'Wrong Odds', N'赔率显示错误' )

--TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (6, 125)



