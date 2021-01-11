/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Max
	Date 20210105
	Task: TVS - Update message template for "Parlay Count as 1" - [Redmine: 148252]
	DB: DBTXN/bodb02
	
*/ 
USE bodb02
GO

SELECT * INTO #temp
FROM TicketVoiding_MessageTemplate m WITH (NOLOCK)
WHERE MsgEnglish LIKE '%Parlay counted as (1)%'

UPDATE t WITH (ROWLOCK, UPDLOCK)
	SET t.MsgEnglish = REPLACE(t.MsgEnglish, 'Parlay counted as (1)', 'Parlay counted as one (1)')
		,t.MsgChineseTraditional = REPLACE(t.MsgChineseTraditional, N'過關以(1)計算', N'串關以(1)計算')
		,t.MsgChineseSimplified = REPLACE(t.MsgChineseSimplified, N'过关以(1)计算', N'串关以(1)计算')
		,t.MsgChineseNewSimplified = REPLACE(t.MsgChineseNewSimplified, N'过关以(1)计算', N'串关以(1)计算')
FROM TicketVoiding_MessageTemplate t
	INNER JOIN #temp tmp ON tmp.TemplateId = t.TemplateId

DROP TABLE #Temp


