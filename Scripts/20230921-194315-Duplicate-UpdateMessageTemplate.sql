/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20230921@Max
	Task: [TVS] Duplicate Tickets - Not display "Kindly double check..." in message template when voiding settled ticket [Redmine: #194315]
	DB: DBCTG/bodb02
*/
USE bodb02
GO


--TicketVoiding_MessageTemplate
UPDATE m SET 
	m.MsgEnglish = 'Attn:[{{Sport type}}] Due to technical error, bet ID: "@@" is considered VOID. {{CheckStatement}}Sorry for the inconvenience caused!'
	,m.MsgChineseTraditional = N'請注意:[{{Sport type}}] 由於技術有誤, 注單: "@@" 已被作廢. {{CheckStatement}}不便之處 敬請見諒!'
	,m.MsgChineseSimplified = N'请注意:[{{Sport type}}] 由于技术有误, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
	,m.MsgChineseNewSimplified = N'请注意:[{{Sport type}}] 由于技术有误, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 64

UPDATE m SET
	m.MsgEnglish = 'Attn: [Mix Parlay] Due to technical error, bet ID: "@@" is considered VOID. {{CheckStatement}}Sorry for the inconvenience caused!'
	,m.MsgChineseTraditional = N'請注意:[串關] 由於技術有誤, 注單: "@@" 已被作廢. {{CheckStatement}}不便之處 敬請見諒!'
	,m.MsgChineseSimplified = N'请注意:[串关] 由于技术有误, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
	,m.MsgChineseNewSimplified = N'请注意:[串关] 由于技术有误, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
FROM dbo.TicketVoiding_MessageTemplate m WITH (ROWLOCK, UPDLOCK)
WHERE m.TemplateId = 65




