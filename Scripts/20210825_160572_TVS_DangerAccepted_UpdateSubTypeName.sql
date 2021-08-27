/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210825@July
	Task: TVS - Danger Accepted - Update Sub Type List description - [Redmine: #160572]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'BET/FC Pen Goal/Goal - Home' WHERE SubIssueTypeId = 60
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'BET/FC Pen Goal/Goal - Away' WHERE SubIssueTypeId = 61
UPDATE dbo.TicketVoiding_SubIssueType SET SubIssueTypeName = 'BET/FC Pen Goal/Goal' WHERE SubIssueTypeId = 62