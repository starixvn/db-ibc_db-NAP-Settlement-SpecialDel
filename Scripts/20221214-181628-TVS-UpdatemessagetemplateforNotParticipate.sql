/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20221214@July
	Task: [TVS] Update message template for Not Participate case - [Redmine: #181628]
	DB: DBCTG-bodb02
*/

USE bodb02
GO
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId,MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES(
 63
,N'Attn:[{{Sport type}}] Due to Player [{{Player Name}}] did not participate, [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}} which affected are considered VOID. Parlay counted as (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
,N'請注意:[{{Sport type}}] 因参賽者 [{{Player Name}}] 未参賽, [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" {{PlacedFromTimeRange}}{{Score}} 只作廢受影響的注單. 串關以(1)計算. 即时兑现被取消. {{CheckStatement}}不便之處 敬請見諒!'
,N'请注意:[{{Sport type}}] 因参赛者 [{{Player Name}}] 未参赛, [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
,N'请注意:[{{Sport type}}] 因参赛者 [{{Player Name}}] 未参赛, [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" {{PlacedFromTimeRange}}{{Score}} 只作废受影响的注单. 串关以(1)计算. 实时兑现被取消. {{CheckStatement}}不便之处 敬请见谅!'
)
GO

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (117, 18,'Not Participate')
SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
GO

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, Sporttype, SubIssueTypeId) VALUES (63,NULL,117) 
