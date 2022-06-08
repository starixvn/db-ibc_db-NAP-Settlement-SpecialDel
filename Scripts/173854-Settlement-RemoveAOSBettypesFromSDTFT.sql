/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220608@Kathy
	Task	: do not SDT FT for list bettypes [Redmine:#171446]

*/
UPDATE s 
	SET DeterminedType = NULL
FROM	dbo.SettlementSpecialBettypeProfile s WITH(ROWLOCK,UPDLOCK)
WHERE	DeterminedType = 2
		AND bettype IN (399,413,416,493)
