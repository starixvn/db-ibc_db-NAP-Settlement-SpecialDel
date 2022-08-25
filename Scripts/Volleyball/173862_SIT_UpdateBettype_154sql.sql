/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created:20220729@Louisa
    Task: Volleyball AIO [Redmineid:#173862]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220729@Louisa: Replace bettype Volleyball 154 by 3918 due to change request [Redmineid:#173862]
							
	Param's Explanation:
		NOTE: only run on SIT env.

*/

USE bodb02
GO

--5 rows
UPDATE dbo.SettlementSpecialBettypeProfile  WITH(ROWLOCK, UPDLOCK)
SET BetType = 3918
WHERE SportType = 6 
	AND bettype = 154




