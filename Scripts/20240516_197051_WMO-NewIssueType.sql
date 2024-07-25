/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240516@Max 
	Task: [TVS] Wrong Market Offered issue type - [Redmine: #197051]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_RequestDetail
ALTER TABLE dbo.TicketVoiding_RequestDetail ADD AdvancedExtraInfo VARCHAR(MAX)
GO

--TicketVoiding_SubIssueType
UPDATE s SET s.SubIssueTypeName = 'Wrong Market Offered'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 12 AND s.SubIssueTypeId = 33

DELETE dbo.TicketVoiding_SubIssueType
WHERE IssueTypeId = 12 AND SubIssueTypeId = 34

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0,	33,	'Wrong Market Offered',	N'盘口错误')

--TicketVoiding_MessageTemplate
UPDATE dbo.TicketVoiding_MessageTemplate
SET MsgEnglish = 'Attn:[{{Sport type}}] Due to {{SpecialBetType}}wrong market offered on Live betting for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
   ,MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}滾球賽事盤口錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}] , 注單: "@@" {{PlacedFromTimeRange}}只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
   ,MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}滚球赛事盘口错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
   ,MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}滚球赛事盘口错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 35

UPDATE dbo.TicketVoiding_MessageTemplate
SET JsonValue = NULL
WHERE TemplateId = 35

--TicketVoiding_MessageTemplateSetting
DELETE dbo.TicketVoiding_MessageTemplateSetting
WHERE SubIssueTypeId = 34


