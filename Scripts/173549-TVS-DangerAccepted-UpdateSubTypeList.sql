/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220601@July
	Task: TVS - Danger Accepted issue type - Update Sub Type List - [Redmine: #173549]
	DB: DBTXN-bodb02

*/
USE bodb02
GO

UPDATE dbo.TicketVoiding_SubIssueType WITH(ROWLOCK,UPDLOCK)
SET	SubIssueTypeName = N'Goal/PEN Foul (Admin TV) - Home'
WHERE SubIssueTypeId = 82

UPDATE dbo.TicketVoiding_SubIssueType WITH(ROWLOCK,UPDLOCK)
SET	SubIssueTypeName = N'Goal/PEN Foul (Admin TV) - Away'
WHERE SubIssueTypeId = 83

UPDATE dbo.TicketVoiding_SubIssueType WITH(ROWLOCK,UPDLOCK)
SET	SubIssueTypeName = N'Goal/PEN Foul (Admin TV)'
WHERE SubIssueTypeId = 84

