/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*  Created: 20220315@Kathy
	Task: add new column [Redmine:#166072 ]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

UPDATE dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET GroupType =  'FT'
WHERE	SportType = 1
		AND SettleType = 'MNL'
		AND GroupType = '2H'

UPDATE dbo.SettlementSpecialBettypeProfile WITH(ROWLOCK, UPDLOCK)
	SET GroupType =  'HT'
WHERE	SportType = 1
		AND SettleType = 'MNL'
		AND GroupType = '1H'