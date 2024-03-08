/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240308@Aries
	Task: Direct Ice Hockey [Redmine:#201129]
	DB: DBPRO/bodb02
*/
USE bodb02
GO

UPDATE SettlementResultTableSetting
SET  Setting = 1
WHERE Sporttype = 4
