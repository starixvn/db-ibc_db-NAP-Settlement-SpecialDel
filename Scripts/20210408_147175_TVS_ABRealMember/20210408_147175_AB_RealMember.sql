/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210408@July
	Task: [TVS] New Issue Type - AB (Real Member)- [Redmine: #147175]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeName) VALUES ('AB (Real Member)')

INSERT INTO dbo.TicketVoiding_SubIssueType (IssueTypeId, SubIssueTypeName,SubIssueTypeNameCS)
SELECT	15,
		SubIssueTypeName,
		SubIssueTypeNameCS
FROM dbo.TicketVoiding_SubIssueType WITH(NOLOCK)
WHERE IssueTypeId = 11

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,41)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,42)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,43)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,44)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,45)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,46)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,47)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,48)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (34,NULL,49)

INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,41,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,42,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,43,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,44,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,45,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,46,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,47,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,48,'Abnormal bet',N'由于非正常投注')
INSERT INTO dbo.TicketVoiding_ReasonTemplate(Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,49,'Abnormal bet',N'由于非正常投注')
