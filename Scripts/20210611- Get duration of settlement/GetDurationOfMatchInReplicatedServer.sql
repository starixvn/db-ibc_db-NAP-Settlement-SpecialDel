/*<info serverAlias="DBAGE-bodb02,DBEXT-bodb02,DBACC-bodb02" executers="" viewers="" isFunction="0"></info>*/  
/*
	Created: 20210611@Kathy
	DB: ReplicatedServer.bodb02
	Task: Check number of settlement command for CAL-HT, CAL-FT action
	
*/
USE bodb02
GO

DECLARE @CheckTime DATETIME = ''
		,@MatchId VARCHAR(20) = 0
		,@Action VARCHAR(10) = 'CAL-HT' -- CAL-HT, CAL-FT

SELECT DATEDIFF(ms, MIN(creationTime), MAX(creationtime)) AS 'Duration'
FROM	sb.CalculationLogs with(nolock)
WHERE	message_body LIKE '%' + @MatchId + '%'
		AND message_body LIKE '%NAP_Admin_Calculate_Main%'
		AND (message_body LIKE '%@action = ''' + @Action + '''%' OR message_body LIKE '%@mode = '''+ @Action + '''%')
		AND creationTime > @CheckTime


SELECT	COUNT(1) 'Number of command'
FROM	sb.CalculationLogs with(nolock)
WHERE	message_body LIKE '%' + @MatchId + '%'
		AND message_body LIKE '%NAP_Admin_Calculate_Main%'
		AND (message_body LIKE '%@action = ''' + @Action + '''%' OR message_body LIKE '%@mode = '''+ @Action + '''%')
		AND creationTime > @CheckTime
