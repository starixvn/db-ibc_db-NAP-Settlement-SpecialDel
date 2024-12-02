/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20241021@Max
	Task: [TVS] New Issue Type - Other Issues [Redmine: #211913]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_SubIssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName)
VALUES (18, 130, 'Restart'), (18, 131, 'Should Not Offer')
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 130, 'Restart', N'重赛' )
	,(0, 131, 'Should Not Offer', N'不應提供' )

--TicketVoiding_MessageTemplate
INSERT INTO dbo.TicketVoiding_MessageTemplate (TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(70,
	'Attn:[{{Sport type}}] Due to Map {{Map}}has been restarted, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}} which affected are considered VOID (Except those products which have been determined the win loss). Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
	,N'請注意:[{{Sport type}}] 由於地圖{{Map}}重赛, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}} 只作廢受影響的注單 (投注結果已確定输赢除外). 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] 由于地图{{Map}}重赛, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单 (投注结果已确定输赢除外). 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] 由于地图{{Map}}重赛, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单 (投注结果已确定输赢除外). 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
),
(71,
	'Attn:[{{Sport type}}] Due to should not offer {{SpecialBetType}}market for the match between, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}} which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
	,N'請注意:[{{Sport type}}] 由於賽事不應提供 "{{SpecialBetType}}" 盤口於, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] 由于赛事不应提供 "{{SpecialBetType}}" 盘口于, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] 由于赛事不应提供 "{{SpecialBetType}}" 盘口于, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
)

--TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (70, 130)
, (71, 131) 



