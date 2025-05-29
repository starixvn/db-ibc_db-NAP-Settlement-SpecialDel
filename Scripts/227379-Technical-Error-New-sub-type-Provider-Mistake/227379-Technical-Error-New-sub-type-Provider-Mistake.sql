/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250519@Hyman
	Task: 227379-Technical-Error-New-sub-type-Provider-Mistake[Redmine: #227379]
	DB: DBCTG/bodb02
*/
SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO [bodb02].[dbo].[TicketVoiding_SubIssueType] 
(SubIssueTypeId, IssueTypeId, SubIssueTypeName, SubIssueTypeNameCS)
VALUES (149, 24, 'Provider Mistake', N'供應商錯誤');
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

INSERT INTO [bodb02].[dbo].[TicketVoiding_ReasonTemplate]
(Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 149, 'Provider Mistake', N'供應商錯誤');


INSERT INTO [bodb02].[dbo].[TicketVoiding_MessageTemplateSetting]
(TemplateId, Sporttype, SubIssueTypeId)
VALUES (64, NULL, 149);

ALTER TABLE Ticketvoiding_VoidBetAutomation_Service
ADD IsSentToMTS BIT NULL;