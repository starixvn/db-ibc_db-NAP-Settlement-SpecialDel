/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/  
/*
	Created: 20210611@Kathy
	DB: DBTXN.bodb02
	Task: Check number of settlement command for CAL-HT, CAL-FT action
	
*/
USE bodb02
GO

DECLARE @matchid INT = 0
	,@Action VARCHAR(10) = 'CAL-FT' -- CAL-HT, CAL-FT

SELECT	*
FROM	dbo.single_calculate_queue WITH(NOLOCK)
WHERE	matchid = @matchid
		AND Action IN ('CAL-HT', 'CAL-FT')

SELECT	COUNT(1) AS 'Number Of Command', COUNT(1) * 2 + 2 'Number Of Log On Replicated Server'
FROM	dbo.SingleSettlementTrace WITH(NOLOCK)
WHERE	matchid = @matchid
		AND SqlCommand LIKE  '%@action = ''' + @Action + '''%'