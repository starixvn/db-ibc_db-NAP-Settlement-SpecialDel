/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250519@Hyman
	Task: 227379-Technical-Error-New-sub-type-Provider-Mistake[Redmine: #227379]
	DB: DBCTG/bodb02
*/
INSERT INTO [bodb02].[dbo].[TicketVoiding_SubIssueType] 
(SubIssueTypeId, IssueTypeId, SubIssueTypeName, SubIssueTypeNameCS)
VALUES (149, 24, 'Provider Mistake', N'供應商錯誤');

INSERT INTO [bodb02].[dbo].[TicketVoiding_ReasonTemplate]
(Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (NULL, 149, 'Provider Mistake', N'供應商錯誤');


INSERT INTO [bodb02].[dbo].[TicketVoiding_MessageTemplateSetting]
(TemplateId, Sporttype, SubIssueTypeId, IsCheckedVar)
VALUES (64, NULL, 149, NULL);