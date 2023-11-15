/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20231002@Max 
	Task: [TVS] Not Participant issue type - [Redmine: #192832]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (21, 'Not Participate')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
UPDATE s SET s.IssueTypeId = 21
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 18 AND s.SubIssueTypeId = 117

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (50, 117, 'Did not participate',N'未参賽' )

--TicketVoiding_MessageTemplate
UPDATE m SET
	m.MsgEnglish = 'Attn:[{{Sport type}}] Due to Player [{{Player Name}}] did not participate, [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
	,m.MsgChineseTraditional = N'請注意:[{{Sport type}}] 因参賽者 [{{Player Name}}] 未参賽, [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
	,m.MsgChineseSimplified = N'请注意:[{{Sport type}}] 因参赛者 [{{Player Name}}] 未参赛, [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
	,m.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 因参赛者 [{{Player Name}}] 未参赛, [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 63



