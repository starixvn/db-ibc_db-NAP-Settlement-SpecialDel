/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240510@Aries
	Task: Enhance SOP-Refund for Soccer's Early results [Redmine:#201462]
	DB: DBPRO/bodb02
*/
USE bodb02
GO

UPDATE SettlementResultTableSetting
SET  Setting = 1
WHERE Sporttype = 1
