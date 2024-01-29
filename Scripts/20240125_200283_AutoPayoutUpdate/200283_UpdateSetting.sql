/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240125@Aries
	Task: Failed AutoPayout due to confirmed score 2 times from providers [Redmine:#200283]
	DB: DBPRO/bodb02
*/
USE bodb02
GO

UPDATE SettlementResultTableSetting
SET  AP_Group = 1
WHERE Sporttype = 5
