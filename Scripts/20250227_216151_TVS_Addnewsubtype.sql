/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250227@Lani
	Task: TVS - Wrong Score - Add new sub type and related event function [Redmine: #216151]
	DB: DBCTG-bodb02
*/

USE bodb02
GO
-------dbo.TicketVoiding_SubIssueType
SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON

--Home/Away Corner (No Onwards/Onwards) Main Subtype
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (132, 3, 'No Indication Home Corner (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (133, 3, 'No Indication Home Corner (Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (134, 3, 'No Indication Away Corner (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (135, 3, 'No Indication Away Corner (Onwards)')
--Home/Away Goal Kick (No Onwards/Onwards) Main Subtype
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (136, 3, 'No Indication Home Goal Kick (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (137, 3, 'No Indication Home Goal Kick (Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (138, 3, 'No Indication Away Goal Kick (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (139, 3, 'No Indication Away Goal Kick (Onwards)')

--Child sub type
--Goal
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (140, 3, 'Next Goal - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (141, 3, 'Next Goal - Away')
--Corner
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (142, 3, 'Next Corner - Home')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (143, 3, 'Next Corner - Away')
--Next Goal/Goal kick/Booking/Corner
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (144, 3, 'Next Booking')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (145, 3, 'Next Goal')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (146, 3, 'Next Goal Kick')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (147, 3, 'Next Corner')

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
-------dbo.TicketVoiding_MessageTemplateSetting
--No onwards
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (7,NULL,132)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (7,NULL,134)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (7,NULL,136)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (7,NULL,138)
--Onwards
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (36,NULL,133)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (36,NULL,135)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (36,NULL,137)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (36,NULL,139)
--Next goal
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (46,NULL,145)
--Next corner
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (33,NULL,147)
--Next goal kick
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (43,NULL,146)
--Next booking
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,Sporttype,SubIssueTypeId) VALUES (40,NULL,144)

-----------dbo.TicketVoiding_ReasonTemplate
--No onwards
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,132,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,134,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,136,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,138,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
--Onwards
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,133,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,135,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,137,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,139,'Soccer - Wrong Score',N'足球 - 由于比分显示错误')
--Next goal
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,145,'Soccer - Danger Accept In Goal',N'足球 - 有进球的危险时段中误被接受')
--Next corner
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,147,'Soccer - Danger Accept In Corner',N'足球 - 在有角球的危险时段中误被接受')
--Next goal kick
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,146,'Soccer - Goal Kick has been completed',N'足球 - 龙门球赛事已结束')
--Next booking
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype,SubIssueTypeId,ReasonEnglish,ReasonChineseSimplified) VALUES (0,144,'Soccer - Booking has been completed',N'足球 - 罚牌赛事已结束')





