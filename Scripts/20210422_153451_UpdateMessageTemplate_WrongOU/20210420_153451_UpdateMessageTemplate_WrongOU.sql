/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210422@July
	Task: [TVS] Update message template of Wrong OU - [Redmine: #153451]
	DB: DBTXN-bodb02
*/


SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (50, 6,'Scheduled Overs Being Reduced')
SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
GO
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified, JsonValue)
VALUES(
 38
,'Attn:[{{Sport type}}] Due to the number of scheduled overs being reduced for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" placed at "OU-{{Wrong Market}} onwards" {{FromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 由於比賽輪數减少 "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 投注於 "大小盤-{{Wrong Market}} 開始" {{FromTimeRange}}{{Score}}只作廢受影響的注單. 串關以(1)計算. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 由于比赛轮数减少 "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}} 开始" {{FromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 由于比赛轮数减少 "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 投注于 "大小盘-{{Wrong Market}} 开始" {{FromTimeRange}}{{Score}}只作废受影响的注单. 串关以(1)计算. {{CheckStatement}}不便之处 敬请见谅!'
,N'[{"Name":"Wrong Market","MsgEnglish":"Wrong Market","MsgChineseTraditional":"Wrong Market (TC)","MsgChineseSimplified":"Wrong Market (SC)","MsgChineseNewSimplified":"Wrong Market (New SC)"}]'
)
GO
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (38,50)