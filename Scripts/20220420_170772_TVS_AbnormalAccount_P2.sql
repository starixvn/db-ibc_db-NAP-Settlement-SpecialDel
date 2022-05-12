/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20220421@July 
	Task: TVS - Abnormal Account - Phase 2 [Redmine: #170772]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

INSERT INTO TicketVoiding_SubIssueType (IssueTypeId, SubIssueTypeName, SubIssueTypeNameCS)
SELECT 13,SubIssueTypeName,SubIssueTypeNameCS
FROM TicketVoiding_SubIssueType WITH(NOLOCK)
WHERE SubIssueTypeId IN (28,29,30,31,32,36,37,38)

GO

UPDATE TicketVoiding_SubIssueType 
SET  SubIssueTypeName = N'Abnormal'
	,SubIssueTypeNameCS = N'非正常'
WHERE SubIssueTypeId = 39

GO

INSERT INTO TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
SELECT 37, SubIssueTypeId
FROM TicketVoiding_SubIssueType
WHERE SubIssueTypeId IN (100,101,102,103,104,105,106,107)

GO

INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
SELECT 0, SubIssueTypeId, 'Abnormal bet', N'非正常投注'
FROM TicketVoiding_SubIssueType
WHERE SubIssueTypeId IN (100,101,102,103,104,105,106,107)

GO
