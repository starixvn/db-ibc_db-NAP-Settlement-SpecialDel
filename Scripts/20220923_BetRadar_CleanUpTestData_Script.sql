/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220923@Victoria
    Task: Delete unused test data of BetRadar
    DB: DBTXN-bodb02

	 Revisions:
		- 20220923@Victoria: Delete unused test data of BetRadar [Redmineid:#178134] 
							
*/

USE bodb02

DELETE b
FROM bettransm b WITH (ROWLOCK)
WHERE b.TransId IN (1344535919, 1344535992, 1344536044, 1344536089, 1344536112, 1344548627, 1344548731 ,1344548763, 1344548832, 1344548982, 1344549079)
	AND betcheck LIKE 'Test Player%'
