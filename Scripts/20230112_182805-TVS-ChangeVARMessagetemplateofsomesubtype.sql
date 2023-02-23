/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230208@July
	Task: [TVS] Update VAR Message - [Redmine: #182805]
	DB: DBCTG-bodb02
*/

USE bodb02
GO

--2. Remove VAR Message of subtypes "No Indication Home/Away Goal (No Onwards/Onwards)"
DELETE FROM dbo.TicketVoiding_MessageTemplateSetting
WHERE SubIssueTypeId in (7,35,94,95) AND IsCheckedVar = 1

--3. Change VAR Message template of some subtype
UPDATE dbo.TicketVoiding_MessageTemplateSetting 
SET TemplateId = 58
WHERE SubIssueTypeId in (1,55,56) AND IsCheckedVar = 1

--4. Update VAR Message template of some subtypes  
UPDATE dbo.TicketVoiding_MessageTemplate
SET MsgEnglish = 'Attn:[{{Sport type}}] Due to a goal was scored from a penalty awarded through VAR review for the match between "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" {{PlacedFromTimeRange}}{{Score}}which affected are considered VOID. Parlay counted as one (1). Cash Out Cancelled. {{CheckStatement}}Sorry for the inconvenience caused!'
WHERE TemplateId = 51
