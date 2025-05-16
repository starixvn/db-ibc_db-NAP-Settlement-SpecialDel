/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20250512@Lani 
	Task: [TVS] New Issue Type "Match Early Completed" - [Redmine: #226438]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (27, 'Match Early Completed')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName)
VALUES (27, 148, 'Match Early Completed')
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 148, 'Match Early Completed',N'賽事提前結束' )


--TicketVoiding_MessageTemplate
INSERT INTO dbo.TicketVoiding_MessageTemplate (TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(72,
	'Attn:[{{Sport type}}] The match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}] has been completed earlier {{Inning}}, bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID (Except those products which have been determined the win loss). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
	,N'請注意:[{{Sport type}}] "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 賽事提前{{Inning}}結束, 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單 (投注結果已確定输赢除外). 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 赛事提前{{Inning}}结束, 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单 (投注结果已确定输赢除外). 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 赛事提前{{Inning}}结束, 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单 (投注结果已确定输赢除外). 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
)

--TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (72, 148)



