/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*  Created: 20220404@Kathy
	Task: update data [Redmine:#170551]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

UPDATE dbo.SettlementResultTableSetting WITH(ROWLOCK, UPDLOCK)
	SET IsSettleByProfile = 1
WHERE Sporttype = 1

GO