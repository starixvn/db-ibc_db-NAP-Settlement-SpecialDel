/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20230606@July 
	Task: [TVS] Reduced Over - [Redmine: #185833]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

INSERT INTO TicketVoiding_IssueType (IssueTypeName)
VALUES ('Reduced Over')

INSERT INTO TicketVoiding_SubIssueType (IssueTypeId,SubIssueTypeName)
VALUES (19,'Reduced Over')

INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (50, 122, 'Reduced Over',N'由于比赛轮数减少' )

INSERT INTO TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (38,122)


