/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210507@July
	Task: [TVS] Auto select bet types on Void Single Bet - [Redmine: #154620]
	DB: DBTXN-bodb02
*/

USE bodb02
GO
--Add new issue type Wrong Quarter HDP
SET IDENTITY_INSERT TicketVoiding_IssueType ON
INSERT INTO dbo.TicketVoiding_IssueType (IssueTypeId, IssueTypeName) VALUES (16,'Wrong Quarter HDP')
SET IDENTITY_INSERT TicketVoiding_IssueType OFF

GO
SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName) VALUES (51,16,'Wrong Quarter HDP')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName) VALUES (52,16,'Away Virtual Head Reversed')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName) VALUES (53,16,'Home Virtual Head Reversed')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

GO
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (8,51)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (29,52)
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (30,53)

GO

--Add new sub issue type Wrong Quarter OU under Wrong OU
SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId, SubIssueTypeName) VALUES (54,6,'Wrong Quarter OU')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId,SubIssueTypeId) VALUES (10,54)