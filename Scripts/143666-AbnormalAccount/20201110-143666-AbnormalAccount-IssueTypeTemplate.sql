/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20201110@Max 
	Task: [TVS] Abnormal Account - [Redmine: #143666]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

SET IDENTITY_INSERT TicketVoiding_IssueType ON
INSERT INTO TicketVoiding_IssueType (IssueTypeId,IssueTypeName)
VALUES (13,'Abnormal Account')
SET IDENTITY_INSERT TicketVoiding_IssueType OFF

SET IDENTITY_INSERT TicketVoiding_SubIssueType ON
INSERT INTO TicketVoiding_SubIssueType (SubIssueTypeId,IssueTypeId,SubIssueTypeName)
VALUES (39,13,'Abnormal Account')
SET IDENTITY_INSERT TicketVoiding_SubIssueType OFF

INSERT INTO TicketVoiding_ReasonTemplate (Sporttype, SubIssueTypeId, ReasonEnglish, ReasonChineseSimplified)
VALUES (0, 39, 'Abnormal bet',N'非正常投注' )
GO

INSERT [dbo].[TicketVoiding_MessageTemplate] ([TemplateId], [MsgEnglish], [MsgChineseTraditional]
, [MsgChineseSimplified]
, [MsgChineseNewSimplified]
, [JsonValue]) 
VALUES (39, N'Attn: Due to abnormal bets, bet ID: "@@" is considered VOID. Kindly double check your statement again. Sorry for the inconvenience caused!'
, N'請注意: 由於非正常投注, 注單: "@@" 已被作廢. 不便之處 敬請見諒!'
, N'请注意: 由于非正常投注, 注单: "@@" 已被作废. 不便之处 敬请见谅!'
, N'请注意: 由于非正常投注, 注单: "@@" 已被作废. 不便之处 敬请见谅!'
, N'')
,(40, N'Attn: Due to abnormal bets, bet ID: "@@" is considered VOID. Kindly double check your statement again. Sorry for the inconvenience caused! '
, N'請注意: 由於非正常投注, 注單: "@@" 已被作廢. 請重新檢查您的帳目. 不便之處 敬請見諒!'
, N'请注意: 由于非正常投注, 注单: "@@" 已被作废. 请重新检查您的帐目. 不便之处 敬请见谅!'
, N'请注意: 由于非正常投注, 注单: "@@" 已被作废. 请重新检查您的帐目. 不便之处 敬请见谅!'
, N'')

INSERT INTO TicketVoiding_MessageTemplateSetting (TemplateId, SubIssueTypeId)
VALUES (39,39), (40,39)