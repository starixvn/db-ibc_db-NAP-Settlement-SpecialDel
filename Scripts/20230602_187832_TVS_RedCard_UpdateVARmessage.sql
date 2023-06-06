/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230208@July
	Task: [TVS] Red Card - Update VAR message for sub type 'Wrong Indication Home RC/Away RC' - [Redmine: #187832]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

-- Change VAR Message template of some subtype
UPDATE dbo.TicketVoiding_MessageTemplateSetting 
SET SubIssueTypeId = 17
WHERE SubIssueTypeId IN (15) AND IsCheckedVar = 1

UPDATE dbo.TicketVoiding_MessageTemplateSetting 
SET SubIssueTypeId = 18
WHERE SubIssueTypeId IN (16) AND IsCheckedVar = 1

