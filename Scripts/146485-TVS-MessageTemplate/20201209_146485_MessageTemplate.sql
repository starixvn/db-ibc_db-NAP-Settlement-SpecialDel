/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20201209@Max
	Task: TVS - Modify message template - [Redmine: #146485]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

-- UPDATE Template 41
UPDATE ms SET ms.Sporttype = NULL
FROM dbo.TicketVoiding_MessageTemplateSetting ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.Id = 79 AND ms.SubIssueTypeId = 40

--DELETE 9999
DELETE dbo.TicketVoiding_MessageTemplateSetting WHERE Id = 80 AND SubIssueTypeId = 40


