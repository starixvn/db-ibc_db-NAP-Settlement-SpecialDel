/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230419@Max
	Task: [TVS] New issue type Wrong Odds [Redmine: #179934]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

--TicketVoiding_SubIssueType
UPDATE s SET s.SubIssueTypeName = 'Handicap'
FROM [dbo].[TicketVoiding_SubIssueType] s WITH (ROWLOCK, UPDLOCK)
WHERE s.SubIssueTypeId = 6

SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO [dbo].[TicketVoiding_SubIssueType] (
	[SubIssueTypeId]
  ,[IssueTypeId]
  ,[SubIssueTypeName]
) 
VALUES (119, 11, '1H Handicap'),
	(120, 11, 'Over/Under'),
	(121, 11, '1H Over/Under')

SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--TicketVoiding_ReasonTemplate
INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 6, 'Wrong Odds',N'赔率显示错误' )
	,(0, 119, 'Wrong Odds',N'赔率显示错误' )
	,(0, 120, 'Wrong Odds',N'赔率显示错误' )
	,(0, 121, 'Wrong Odds',N'赔率显示错误' )

--TicketVoiding_MessageTemplate
UPDATE m SET
	m.MsgEnglish = 'Attn:[{{Sport type}}] Due to {{SpecialBetType}} wrong odds displayed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID{{AIOMessage}}. Parlay counted as one (1). Cash Out Cancelled. The actual market is "{{Actual Market}}". {{CheckStatement}}Sorry for the inconvenience caused!'
	,m.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於 {{SpecialBetType}} 賠率顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}}只作廢受影響的注單{{AIOMessage}}. 串關以(1)計算. 即时兑现被取消. 正確盤口為 "{{Actual Market}}". {{CheckStatement}}不便之處 敬請見諒!'
	,m.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}} 赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
	,m.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于 {{SpecialBetType}} 赔率显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}}只作废受影响的注单{{AIOMessage}}. 串关以(1)计算. 实时兑现被取消. 正确盘口为"{{Actual Market}}". {{CheckStatement}}不便之处 敬请见谅!'
FROM TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 6

--TicketVoiding_MessageTemplateSetting
UPDATE ms SET ms.Sporttype = 1
FROM dbo.TicketVoiding_MessageTemplateSetting ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.Id = 11

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) 
VALUES (6,1,119),
	(6,1,120),
	(6,1,121),
	(9999,NULL,6),
	(9999,NULL,119),
	(9999,NULL,120),
	(9999,NULL,121)
	

