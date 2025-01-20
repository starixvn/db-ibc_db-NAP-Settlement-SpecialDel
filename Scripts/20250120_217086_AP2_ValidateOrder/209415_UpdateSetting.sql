/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250120@Aries
	Task: Enhance the Validate Order for Auto Payout2 [Redmine:#217086]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
UPDATE SettlementResultTableSetting
SET  AP_EAR_CheckList  = '4,1,2,3,93,99'
WHERE Sporttype = 6
GO
UPDATE SettlementResultTableSetting
SET  AP_Main_CheckList  = '4,1,2,3,92,97,99'
WHERE Sporttype = 8
GO