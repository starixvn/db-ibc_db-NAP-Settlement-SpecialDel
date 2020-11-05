/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created by: 20201102@Max
	Task: TVS - Enhance 4 Danger Accept + Wrong Red Card IssueType [Redmine: #143091, #140951]
	DB: DBTXN/bodb02
*/
USE [bodb02]
GO

--TicketVoiding_MessageTemplate
UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to bets erroneously accepted in goal danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 1

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to bets erroneously accepted in corner danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 2

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to bets erroneously accepted in booking danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 3

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to bets erroneously accepted in home red card danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 4

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to bets erroneously accepted in away red card danger play during the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 5

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 22

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to wrong market offered caused by no indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 23

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Home red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 24

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to wrong market offered caused by wrong indication of Away red card, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 25

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to red card being awarded to Home team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 26

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to red card being awarded to Away team under Regular Time on match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 27

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to wrong odds offered on replacement of sent-off player for match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 28

UPDATE m
SET m.MsgEnglish = 'Attn:[{{Sport type}}] Due to {{Next Corner}} corner has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange_NC}}which affected are considered VOID. Parlay counted as (1). {{CheckStatement}}Sorry for the inconvenience caused!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 33

--TicketVoiding_SubIssueType
UPDATE s SET
	s.SubIssueTypeName = 'No Indication Home RC'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 10
	AND s.SubIssueTypeId = 15

UPDATE s SET
	s.SubIssueTypeName = 'No Indication Away RC'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 10
	AND s.SubIssueTypeId = 16

UPDATE s SET
	s.SubIssueTypeName = 'Wrong Indication Home RC'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 10
	AND s.SubIssueTypeId = 17

UPDATE s SET
	s.SubIssueTypeName = 'Wrong Indication Away RC'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 10
	AND s.SubIssueTypeId = 18

UPDATE s SET
	s.SubIssueTypeName = 'Home RC award under regular time'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 10
	AND s.SubIssueTypeId = 19

UPDATE s SET
	s.SubIssueTypeName = 'Away RC award under regular time'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.IssueTypeId = 10
	AND s.SubIssueTypeId = 20
