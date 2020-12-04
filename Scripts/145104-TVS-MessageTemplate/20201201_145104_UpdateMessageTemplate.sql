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

-----New IssueType Template
SET IDENTITY_INSERT TicketVoiding_IssueType ON
INSERT INTO TicketVoiding_IssueType (IssueTypeId,IssueTypeName)
VALUES (14,'Match Completed')
SET IDENTITY_INSERT TicketVoiding_IssueType OFF

SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId,SubIssueTypeName)
VALUES (40,14,'Match Completed')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

INSERT [dbo].[TicketVoiding_MessageTemplate] ([TemplateId], [MsgEnglish], [MsgChineseTraditional]
, [MsgChineseSimplified]
, [MsgChineseNewSimplified]
, [JsonValue]) 
VALUES (41, N'Attn:[{{Sport type}}] Due to "{{Wicket No}} Wicket" has been completed "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
, N'請註意:[{{Sport type}}] 由於 "{{Wicket No}}三柱門" 已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 註單: "@@" {{PlacedFromTimeRange_NC}}只作廢受影響的註單. 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
, N'请注意:[{{Sport type}}] 由于 "{{Wicket No}}三柱门" 已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
, N'请注意:[{{Sport type}}] 由于 "{{Wicket No}}三柱门" 已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange_NC}}只作废受影响的注单. 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
, N'[{"Name":"Wicket No","MsgEnglish":"Wicket No.","MsgChineseTraditional":"Wicket No. (TC)","MsgChineseSimplified":"Wicket No. (SC)","MsgChineseNewSimplified":"Wicket No. (New SC)","Pattern":"Ex: 2nd"}]')

INSERT INTO TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId, Sporttype)
VALUES (41,40,50),(9999,40,NULL)
