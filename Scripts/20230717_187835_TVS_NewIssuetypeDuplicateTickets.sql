/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20230717@Max
	Task: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (20, 'Duplicate Tickets')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName)
VALUES (20, 122, 'Duplicate Tickets')
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 122, 'Technical Error', N'由于技术有误' )

--TicketVoiding_MessageTemplate
INSERT INTO dbo.TicketVoiding_MessageTemplate (TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(64,
	'Attn:[{{Sport type}}] Due to technical error, bet ID: "@@" is considered VOID. Sorry for the inconvenience caused!'
	,N'請注意:[{{Sport type}}] 由於技術有誤, 注單: "@@" 已被作廢. 不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] 由于技术有误, 注单: "@@" 已被作废. 不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] 由于技术有误, 注单: "@@" 已被作废. 不便之处 敬请见谅!'
),
(65,
	'Attn: [Mix Parlay] Due to technical error, bet ID: "@@" is considered VOID. Sorry for the inconvenience caused!'
	,N'請注意:[串關] 由於技術有誤, 注單: "@@" 已被作廢. 不便之處 敬請見諒!'
	,N'请注意:[串关] 由于技术有误, 注单: "@@" 已被作废. 不便之处 敬请见谅!'
	,N'请注意:[串关] 由于技术有误, 注单: "@@" 已被作废. 不便之处 敬请见谅!'
)

--TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (64, 122)
, (65, 122) 



