/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220413@Kathy
	Task	: Add new column [Redmine:#170551]

*/
USE [bodb02]
GO

UPDATE dbo.SettlementSpecialBettypeProfile
	SET DeterminedType = 2
WHERE	SportType = 1
		AND SettleType = 'MNL'
		AND IsSDT = 1
		AND bettype in (3,4,6,13,14,16,22,26,27,128,130,131,132,133,134,144,145,147,148,149,150,152,159,161,162,163,170,172,189,190,396,397,399,401,402,406,407
				,408,409,413,415,416,417,418,419,420,421,422,423,434,435,436,437,438,439,440
				,441,445,446,447,448,449,450,451,454,461,462,467,473,475,482,483,486,488,493
				,140,141,142,442,443, 444)

GO
