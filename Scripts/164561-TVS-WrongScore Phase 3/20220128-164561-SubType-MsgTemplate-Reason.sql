/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220128@Max
	Task: TVS - Wrong Score Enhancement - Phase 3 - [Redmine: #164561]
	DB: DBTXN-bodb02
*/


USE bodb02
GO

--dbo.TicketVoiding_SubIssueType
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Home Score (No Onwards)' WHERE SubIssueTypeId = 7
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'No Indication Home Score (Onwards)' WHERE SubIssueTypeId = 35

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (94, 3, 'No Indication Away Score (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (95, 3, 'No Indication Away Score (Onwards)')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (96, 3, 'Wrong indication Score (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (97, 3, 'Wrong indication Score (Onwards)')

INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (98, 3, 'Wrong Indication Swap Team Score (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (99, 3, 'Wrong Indication Swap Team Score (Onwards)')

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF

-------dbo.TicketVoiding_MessageTemplate

-------dbo.TicketVoiding_MessageTemplateSetting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (7,NULL,94)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (36,NULL,95)

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (7,NULL,96)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (36,NULL,97)

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (7,NULL,98)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (36,NULL,99)


-----------dbo.TicketVoiding_ReasonTemplate
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,94,'Wrong Score',N'由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,95,'Wrong Score',N'由于比分显示错误')

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,96,'Wrong Score',N'由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,97,'Wrong Score',N'由于比分显示错误')

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,98,'Wrong Score',N'由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (1,99,'Wrong Score',N'由于比分显示错误')




