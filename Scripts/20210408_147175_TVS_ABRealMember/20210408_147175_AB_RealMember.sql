/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210408@July
	Task: [TVS] New Issue Type - AB (Real Member)- [Redmine: #147175]
	DB: DBTXN-bodb02
*/

USE bodb02
GO
SET IDENTITY_INSERT TicketVoiding_IssueType ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName) VALUES (15,'AB (Real Member)')
SET IDENTITY_INSERT TicketVoiding_IssueType OFF

GO
SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (41,15,'Abnormal',N'非正常')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (42,15,'Group Betting',N'群组投注')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (43,15,'Hedging',N'出货集团')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (44,15,'Arbitrage',N'打水套利')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (45,15,'Fixed Game',N'内定赛事')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (46,15,'AB Bet',N'单')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (47,15,'Robot Betting',N'机械投注')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (48,15,'Irrigation Bet',N'灌水投注')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS) VALUES (49,15,'System Formula Bet',N'系统计算投注')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

GO
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,41)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,42)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,43)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,44)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,45)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,46)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,47)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,48)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (34,49)

GO
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,41,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,42,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,43,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,44,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,45,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,46,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,47,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,48,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,49,'Abnormal bet',N'由于非正常投注')

GO
