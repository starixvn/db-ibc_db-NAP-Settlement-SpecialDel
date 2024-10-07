/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240925@July
	Task: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (26, 'Wrong Offered Name')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] ON
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName) VALUES (26, 126, 'Team Name (English)')
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName) VALUES (26, 127, 'Team Name (Chinese)')
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName) VALUES (26, 128, 'League Name (English)')
INSERT INTO dbo.TicketVoiding_SubIssueType(IssueTypeId, SubIssueTypeId, SubIssueTypeName) VALUES (26, 129, 'League Name (Chinese)')
SET IDENTITY_INSERT [dbo].[TicketVoiding_SubIssueType] OFF

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified) VALUES (0, 126, 'Wrong Team Name', N'队名错误' )
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified) VALUES (0, 127, 'Wrong Team Name', N'队名错误' )
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified) VALUES (0, 128, 'Wrong League Name', N'联赛名错误' )
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified) VALUES (0, 129, 'Wrong League Name', N'联赛名错误' )

--TicketVoiding_MessageTemplate
INSERT INTO dbo.TicketVoiding_MessageTemplate (TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(13,
	'Attn:[{{Sport type}}] Due to wrong team name displayed, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" which affected are considered VOID. Parlay counted as one (1). The actual team name is "{{Home team name}} -vs- {{Away team name}}". {{CheckStatement}}Sorry for the inconvenience caused!'
	,N'請注意:[{{Sport type}}] 由於英文隊名顯示有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 只作廢受影響的注單 (請查閱英文隊名, 以英文為準). 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] 由于英文队名显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 只作废受影响的注单 (请查阅英文队名, 以英文为准). 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] 由于英文队名显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 只作废受影响的注单 (请查阅英文队名, 以英文为准). 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
),
(15,
	'Attn:[{{Sport type}}] Due to wrong league name displayed, the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" which affected are considered VOID. The actual league name is "{{League name}}". Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
	,N'請注意:[{{Sport type}}] 由於英文聯賽名顯示有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 只作廢受影響的注單 (請查閱英文隊名, 以英文為準). 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] 由于英文联赛名显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 只作废受影响的注单 (请查阅英文队名, 以英文为准). 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] 由于英文联赛名显示有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 只作废受影响的注单 (请查阅英文队名, 以英文为准). 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
,
(68,
	N'请查阅中文信息"@@"'
	,N'請注意:[{{Sport type}}] 由於隊名顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 已被作廢. 正確之隊名為 "{{Home team name}} -vs- {{Away team name}}". 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] 由于队名显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 已被作废. 正确之队名为 "{{Home team name}} -vs- {{Away team name}}". 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] 由于队名显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 已被作废. 正确之队名为 "{{Home team name}} -vs- {{Away team name}}". 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)
,
(69,
	N'请查阅中文信息"@@"'
	,N'請注意:[{{Sport type}}] 由於聯賽顯示錯誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 已被作廢. 正確之隊名為 "{{League name}}". 過關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
	,N'请注意:[{{Sport type}}] 由于联赛显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 已被作废. 正确之队名为 "{{League name}}". 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
	,N'请注意:[{{Sport type}}] 由于联赛显示错误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 已被作废. 正确之队名为 "{{League name}}". 过关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
)

--TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (13, 126)
	 , (68, 127) 
	 , (15, 128) 
	 , (69, 129) 
