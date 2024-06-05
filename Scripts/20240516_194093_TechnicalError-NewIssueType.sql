/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240516@July 
	Task: [TVS] Technical Error issue type - [Redmine: #194093]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (24, 'Technical Error')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
UPDATE s SET s.IssueTypeId = 24
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 18 AND s.SubIssueTypeId = 108

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 108, 'Technical Error',N'技术有误' )

UPDATE dbo.TicketVoiding_MessageTemplate
SET MsgEnglish = 'Attn:[{{Sport type}}] Due to {{SpecialBetType}}technical error, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}技術有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}技术有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}技术有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 48


