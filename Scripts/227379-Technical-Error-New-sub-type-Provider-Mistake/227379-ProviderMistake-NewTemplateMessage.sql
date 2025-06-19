/*<info serverAlias="DBCTG-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250604@Raymond
	Task: 227379-Technical-Error-New-sub-type-Provider-Mistake[Redmine: #227379]
	DB: DBCTG/bodb02
*/
INSERT INTO dbo.TicketVoiding_MessageTemplate(TemplateId, MsgEnglish, MsgChineseTraditional, MsgChineseSimplified, MsgChineseNewSimplified)
VALUES ( 73
		,N'Attn:[{{Sport type}}] Due to technical error, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], bet ID: "@@" is considered VOID. {{CheckStatement}}Sorry for the inconvenience caused!'
		,N'請注意:[{{Sport type}}] 由於技術有誤, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注單: "@@" 已被作廢. {{CheckStatement}}不便之處 敬請見諒!'
		,N'请注意:[{{Sport type}}] 由于技术有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
		,N'请注意:[{{Sport type}}] 由于技术有误, "{{Home team name}} -vs- {{Away team name}}" [{{League name}} - {{Event Date}}{{Event type}}], 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
		);


UPDATE [bodb02].[dbo].[TicketVoiding_MessageTemplateSetting]
SET TemplateId = 73
WHERE SubIssueTypeId = 149;

