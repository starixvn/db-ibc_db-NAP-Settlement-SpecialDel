/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20240923@July
	Task: [TVS] Update script [Redmine: #209348]
	DB: DBCTG/bodb02
*/
USE bodb02
GO

--TicketVoiding_MessageTemplateSetting
UPDATE dbo.TicketVoiding_MessageTemplateSetting
SET SubIssueTypeId = 30
WHERE SubIssueTypeId = 27 AND TemplateId = 37


UPDATE dbo.TicketVoiding_MessageTemplateSetting
SET SubIssueTypeId = 102
WHERE SubIssueTypeId = 39 AND TemplateId = 37



