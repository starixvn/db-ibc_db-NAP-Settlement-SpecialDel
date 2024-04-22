/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240411@July 
	Task: [TVS] Abandoned issue type - [Redmine: #202626]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_IssueType
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName)
VALUES (23, 'Abandoned')
SET IDENTITY_INSERT [dbo].[TicketVoiding_IssueType] OFF

--TicketVoiding_SubIssueType
UPDATE s SET s.IssueTypeId = 23
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.SubIssueTypeName = 'Abandoned'

--TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (50, 110, 'Match Abandoned',N'赛事取消' )

--TicketVoiding_MessageTemplate
UPDATE m SET
	m.MsgEnglish = 'Attn:[{{Sport type}}] Due to match was abandoned before the scheduled overs, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
	,m.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於比賽輪數减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
	,m.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
	,m.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于比赛轮数减少, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 50
