/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220630@July
	Task: TVS - Add More Message Templates - [Redmine: #174651]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

SET IDENTITY_INSERT dbo.TicketVoiding_IssueType ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName) VALUES (18, 'Other Issues')
SET IDENTITY_INSERT dbo.TicketVoiding_IssueType OFF


UPDATE dbo.TicketVoiding_SubIssueType
SET SubIssueTypeName = 'Reduced Over', IssueTypeId = 18
WHERE SubIssueTypeId = 50

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (108, 18, 'Technical Error')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (109, 18, 'Game Crashed Void Live')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (110, 18, 'Abandoned')
SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
GO

-------dbo.TicketVoiding_MessageTemplate
--Technical Error
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 48
		,N'Attn:[{{Sport type}}] Due to {{SpecialBetType}}technical error, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}}技術有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}技术有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}}技术有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		)
--Reduced Over
UPDATE dbo.TicketVoiding_MessageTemplate
SET MsgEnglish =N'Attn:[{{Sport type}}] Due to the number of scheduled overs being reduced for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
  , MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比賽輪數减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
  , MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
  , MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 38
--Game Crashed Void Live
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 49
		,N'Attn:[{{Sport type}}] Due to technical issue caused by disruption, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於技术问题中断, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于技术问题中断, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于技术问题中断, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		)
--Abandoned
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 50
		,N'Attn:[{{Sport type}}] Due to match was abandoned before the scheduled overs, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於賽事在預定輪數前取消, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的註單. 串關以(1)計算. 即時兌現被取消. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于赛事在预定轮数前取消, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于赛事在预定轮数前取消, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		)

-------dbo.TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (48,NULL,108)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (49,NULL,109)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (50,NULL,110)


