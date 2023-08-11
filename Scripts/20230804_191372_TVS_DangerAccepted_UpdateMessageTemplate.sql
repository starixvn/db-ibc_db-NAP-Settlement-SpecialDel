/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230810@July
	Task: TVS - Danger Accepted issue type - Update message template for HT/FT subtypes - [Redmine: #191372]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 66
		,N'Attn:[{{Sport type}}] Due to 1st Half has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於賽事上半場已結束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于赛事上半场已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于赛事上半场已结束, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
		)


UPDATE TicketVoiding_MessageTemplate WITH (ROWLOCK, UPDLOCK) 
SET
	MsgEnglish = 'Attn:[{{Sport type}}] Due to match has been completed, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
WHERE TemplateId IN (39,44,45)

DELETE FROM dbo.TicketVoiding_MessageTemplateSetting WHERE SubIssueTypeId IN (86,87,88) AND TemplateId IN (39,44,45)

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (66,1,86)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (66,1,87)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (66,1,88)

UPDATE TicketVoiding_ReasonTemplate 
SET   ReasonEnglish = N'Match Has Been Completed'
	, ReasonChineseSimplified = N'赛事已结束'
WHERE SubIssueTypeId IN (67, 78, 85)

UPDATE TicketVoiding_ReasonTemplate 
SET   ReasonEnglish = N'1st Half Has Been Completed'
	, ReasonChineseSimplified = N'上半场已结束'
WHERE SubIssueTypeId IN (86, 87, 88)


