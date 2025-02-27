/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240524@Aries
	Task: Enhance the AutoPayout2 for Overwatch of eSports [Redmine:#202948]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting
SET  AP_EAR_CheckList  = '1,2,3,94,99'
WHERE Sporttype = 43

 