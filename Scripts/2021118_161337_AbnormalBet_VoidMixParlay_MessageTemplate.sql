/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211118@July
	Task: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
	DB: DBTXN-bodb02
*/

USE bodb02
GO

UPDATE dbo.TicketVoiding_MessageTemplate WITH(ROWLOCK, UPDLOCK)
SET MsgEnglish = N'Attn:{{Parlay}} Due to abnormal bets, bet ID: "@@" is considered VOID. {{CheckStatement}}Sorry for the inconvenience caused!'
	,MsgChineseTraditional = N'請注意:{{Parlay}} 由於非正常投注, 注單: "@@" 已被作廢. {{CheckStatement}}不便之處 敬請見諒!'
	,MsgChineseSimplified = N'请注意:{{Parlay}} 由于非正常投注, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
	,MsgChineseNewSimplified = N'请注意:{{Parlay}} 由于非正常投注, 注单: "@@" 已被作废. {{CheckStatement}}不便之处 敬请见谅!'
WHERE TemplateId = 37
