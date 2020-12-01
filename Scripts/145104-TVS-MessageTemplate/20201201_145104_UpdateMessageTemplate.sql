/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201201@Max
	Task: TVS - Modify message template - [Redmine: #145104]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

--Template 24
UPDATE ms
	SET ms.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於主隊紅牌錯誤顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于主队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于主队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 24

--Template 25
UPDATE ms
	SET ms.MsgChineseTraditional = N'請註意:[{{Sport type}}] 由於客隊紅牌錯誤顯示導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!',
		ms.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于客队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!',
		ms.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于客队红牌错误显示导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId = 25
