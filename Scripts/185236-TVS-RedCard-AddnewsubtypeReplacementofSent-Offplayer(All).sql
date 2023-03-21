/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230317@July
	Task: [TVS] Red Card - Add new subtype Replacement of Sent-Off player (All) - [Redmine: #185236]
	DB: DBCTG-bodb02
*/

USE bodb02
GO
--Add new subissue type Replacement of Sent-Off player (All)
GO
SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName) VALUES (118,10,'Replacement of Sent-Off player (All)')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, Sporttype, SubIssueTypeId) VALUES (28, 1, 118)
INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified) 
VALUES (0, 118, 'Wrong odds offered on replacement of sent-off player',	N'红牌球员被替换导致提供错误的赔率')
