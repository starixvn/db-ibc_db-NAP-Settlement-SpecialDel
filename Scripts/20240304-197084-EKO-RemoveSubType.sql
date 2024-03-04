/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20240304@July 
	Task: Early Kick Off - Remove Sub Type - [Redmine: #197084]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_SubIssueType
UPDATE s SET s.SubIssueTypeName = 'Early Kick Off'
FROM dbo.TicketVoiding_SubIssueType s WITH (ROWLOCK, UPDLOCK)
WHERE s.SubIssueTypeId = 12

--TicketVoiding_ReasonTemplate
DELETE FROM dbo.TicketVoiding_ReasonTemplate WHERE SubIssueTypeId = 13

--TicketVoiding_MessageTemplateSetting
DELETE FROM dbo.TicketVoiding_MessageTemplateSetting WHERE SubIssueTypeId = 13

--TicketVoiding_MessageTemplate
DELETE FROM dbo.TicketVoiding_MessageTemplate WHERE TemplateId IN (13,15,17)



