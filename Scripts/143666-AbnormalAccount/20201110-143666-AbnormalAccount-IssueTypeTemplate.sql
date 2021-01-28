/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20201110@Max 
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

SET IDENTITY_INSERT TicketVoiding_IssueType ON
INSERT INTO TicketVoiding_IssueType (IssueTypeId,IssueTypeName)
VALUES (13,'Abnormal Account')
SET IDENTITY_INSERT TicketVoiding_IssueType OFF

SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId,SubIssueTypeName)
VALUES (39,13,'Abnormal Account')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 39, 'Abnormal bet',N'非正常投注' )
GO

UPDATE  dbo.TicketVoiding_MessageTemplate
SET  MsgEnglish = N'Attn: Due to abnormal bets, bet ID: "@@" is considered VOID. {{CheckStatement}}Sorry for the inconvenience caused!'
	,MsgChineseTraditional = N'請注意: 由於非正常投注, 注單: "@@" 已被作廢. {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意: 由于非正常投注, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意: 由于非正常投注, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 37

INSERT INTO TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (37,39)

DELETE FROM TicketVoiding_MessageTemplate WHERE TemplateId = 38
DELETE FROM TicketVoiding_MessageTemplateSetting WHERE TemplateId = 38
