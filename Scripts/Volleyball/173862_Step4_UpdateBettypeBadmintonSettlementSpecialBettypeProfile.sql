/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created:20220629@Louisa
    Task: Volleyball AIO [Redmineid:#173862]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220629@Louisa: Update config for Badminton bettype 2, 3 [Redmineid:#173862]

	Param's Explanation: 

*/

USE bodb02
GO

BEGIN

	-- 2 rows
	UPDATE sp
	SET ResourceID = '70400'
		,RefResourceId = '00'
	FROM SettlementSpecialBettypeProfile sp WITH(ROWLOCK, UPDLOCK)
	WHERE sp.SportType = 9
	AND sp.BetType  IN (2, 3)

END
GO