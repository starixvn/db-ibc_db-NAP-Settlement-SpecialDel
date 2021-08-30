/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210812@July
	Task: TVS - Enhance for Red Card Issue Type - [Redmine: #157097]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Home RC award under Regular Time' WHERE SubIssueTypeId = 19
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Away RC award under Regular Time' WHERE SubIssueTypeId = 20
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'Replacement of Sent-Off player' WHERE SubIssueTypeId = 21
