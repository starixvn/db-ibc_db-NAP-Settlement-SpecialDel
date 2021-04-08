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

INSERT INTO dbo.TicketVoiding_SubIssueType (IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS)
SELECT	15,
		SubIssueTypeName,
		SubIssueTypeNameCS
FROM dbo.TicketVoiding_SubIssueType WITH(NOLOCK)
WHERE IssueTypeId = 11
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
