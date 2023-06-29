/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230629@Max
	Task: TVS - Void single bet - wrong odds can not load message with sport diff 1 [Redmine: #190427]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

--TicketVoiding_MessageTemplate
UPDATE m SET
	m.MsgEnglish = 'Attn:[{{Sport type}}] Due to {{SpecialBetType}}wrong odds displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
	,m.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}賠率顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即时兑现被取消. 正確盤口為 "{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
	,m.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
	,m.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 6

--TicketVoiding_MessageTemplateSetting
DELETE m 
FROM TicketVoiding_MessageTemplateSetting m 
WHERE TemplateId = 9999 
	AND Sporttype IS NULL 
	AND SubIssueTypeId IN (6,119,120,121)

UPDATE m SET m.Sporttype = NULL
FROM TicketVoiding_MessageTemplateSetting m WITH (ROWLOCK, UPDLOCK)
WHERE TemplateId = 6 
	AND SubIssueTypeId IN (6,119,120,121)
	

