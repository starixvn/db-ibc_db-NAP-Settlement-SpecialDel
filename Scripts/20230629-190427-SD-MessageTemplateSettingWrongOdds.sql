/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230629@Max
	Task: TVS - Void single bet - wrong odds can not load message with sport diff 1 [Redmine: #190427]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

DELETE m 
FROM TicketVoiding_MessageTemplateSetting m 
WHERE TemplateId = 9999 
	AND Sporttype IS NULL 
	AND SubIssueTypeId IN (6,119,120,121)

UPDATE m SET m.Sporttype = NULL
FROM TicketVoiding_MessageTemplateSetting m WITH (ROWLOCK, UPDLOCK)
WHERE TemplateId = 6 
	AND SubIssueTypeId IN (6,119,120,121)
	

