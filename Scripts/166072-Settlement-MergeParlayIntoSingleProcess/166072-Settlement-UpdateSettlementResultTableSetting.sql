/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*  Created: 20220315@Kathy
	Task: update data [Redmine:#166072 ]
	DB: DBTXN-bodb02
*/
USE bodb02
GO

UPDATE dbo.SettlementResultTableSetting WITH(ROWLOCK, UPDLOCK)
	SET IsMergedParlay = 1
WHERE Sporttype = 1

GO