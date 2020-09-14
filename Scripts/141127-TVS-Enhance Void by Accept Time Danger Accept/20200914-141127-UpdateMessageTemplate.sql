/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20200914@Max
	Task: [TVS] Enhance Void by Accept Time in Void Single Bet and TVS Danger Accept - [Redmine: #141127]
	DB: bodb02 - DBTRANS
*/

USE bodb02
GO

UPDATE ms
	SET ms.MsgEnglish = REPLACE(ms.MsgEnglish, 'are considered VOID', 'which affected are considered VOID'),
		ms.MsgChineseTraditional = REPLACE(ms.MsgChineseTraditional, '已被作廢', '只作廢受影響的注單'),
		ms.MsgChineseSimplified = REPLACE(ms.MsgChineseSimplified, '已被作废', '只作废受影响的注单'),
		ms.MsgChineseNewSimplified = REPLACE(ms.MsgChineseNewSimplified, '已被作废', '只作废受影响的注单')
FROM dbo.TicketVoiding_MessageTemplate ms WITH (ROWLOCK, UPDLOCK)
WHERE ms.TemplateId IN (1,2,3,4,5,33,22,23,24,25,26,27,28)