/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250519@Hyman
	Task: 227379-Technical-Error-New-sub-type-Provider-Mistake[Redmine: #227379]
	DB: DBCTG/bodb02
*/
INSERT INTO [bodb02].[dbo].[TicketVoiding_SubIssueType] 
(SubIssueTypeId, IssueTypeId, SubIssueTypeName, SubIssueTypeNameCS)
VALUES (149, 24, 'Provider Mistake', N'供應商錯誤');


IF NOT EXISTS (
    SELECT * FROM sys.columns 
    WHERE Name = N'IsSentResultToMTS' 
      AND Object_ID = Object_ID(N'[bodb02].[dbo].[Ticketvoiding_VoidBetAutomation_Service]')
)
BEGIN
    ALTER TABLE [bodb02].[dbo].[Ticketvoiding_VoidBetAutomation_Service]
    ADD IsSentResultToMTS BIT DEFAULT 0;
END;


INSERT INTO [bodb02].[dbo].[TicketVoiding_ReasonTemplate]
(Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (NULL, 149, 'Provider Mistake', N'供應商錯誤');


INSERT INTO [bodb02].[dbo].[TicketVoiding_MessageTemplateSetting]
(TemplateId, Sporttype, SubIssueTypeId, Id, IsCheckedVar)
VALUES (64, NULL, 149, 0, NULL);