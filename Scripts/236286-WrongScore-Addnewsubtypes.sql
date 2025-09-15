/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250911@July
	Task: [TVS] DA/RC/WS - Update and add new sub issue types - [Redmine: #236286]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType ON
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (150, 3,'Wrong Indication Corner (Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (151, 3,'Wrong Indication Corner (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (152, 3,'Wrong Indication Goal Kick (Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (153, 3,'Wrong Indication Goal Kick (No Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (154, 3,'Wrong Indication Booking (Onwards)')
INSERT INTO dbo.TicketVoiding_SubIssueType (SubIssueTypeId, IssueTypeId, SubIssueTypeName) VALUES (155, 3,'Wrong Indication Booking (No Onwards)')
SET IDENTITY_INSERT dbo.TicketVoiding_SubIssueType OFF
GO

--VAR setting
INSERT INTO dbo.TicketVoiding_MessageTemplateSetting (TemplateId, Sporttype, SubIssueTypeId, IsCheckedVar) 
VALUES 
--Wrong Score
 (61,1,150,1)
,(61,1,151,1)
,(61,1,152,1)
,(61,1,153,1)
,(61,1,154,1)
,(61,1,154,1)
--Onwards
,(36,1,150,NULL)
,(36,1,152,NULL)
,(36,1,154,NULL)
--No Onwards
,(7,1,151,NULL)
,(7,1,153,NULL)
,(7,1,155,NULL)

INSERT INTO dbo.TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES 
 (1,150,'Wrong Score',N'比分显示错误')
,(1,151,'Wrong Score',N'比分显示错误')
,(1,152,'Wrong Score',N'比分显示错误')
,(1,153,'Wrong Score',N'比分显示错误')
,(1,154,'Wrong Score',N'比分显示错误')
,(1,155,'Wrong Score',N'比分显示错误')
