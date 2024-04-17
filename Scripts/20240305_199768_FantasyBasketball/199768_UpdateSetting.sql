/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240305@Aries
	Task: Direct Payout for the Fantasy Match of Basketball [Redmine:#199768]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting
SET  Setting = 11
WHERE Sporttype = 2


GO
UPDATE SettlementResultTableSetting
SET  Setting = 10
WHERE Sporttype = 4
