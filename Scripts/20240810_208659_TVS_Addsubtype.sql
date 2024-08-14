/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230810@July
	Task: TVS - Danger Accepted issue type - Add new sub type - [Redmine: #208659]
	DB: DBCTG-bodb02
*/

USE bodb02
GO
-------dbo.TicketVoiding_SubIssueType
SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (124, 1, 'Penalty Shootout (Retaken)')
SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF

-------dbo.TicketVoiding_MessageTemplate
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 67
		,N'Attn:[{{Sport type}}] Due to wrong market offered caused by penalty retaken, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused! '
		,N'請注意:[{{Sport type}}] 由於點球重踢導致盤口有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒! '
		,N'请注意:[{{Sport type}}] 由于点球重踢导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅! '
		,N'请注意:[{{Sport type}}] 由于点球重踢导致盘口有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅! '
		)  

-------dbo.TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (9999,NULL,124)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (67,1,124)

-----------dbo.TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) 
VALUES (0,124,'Penalty Retaken',N'点球重踢')


