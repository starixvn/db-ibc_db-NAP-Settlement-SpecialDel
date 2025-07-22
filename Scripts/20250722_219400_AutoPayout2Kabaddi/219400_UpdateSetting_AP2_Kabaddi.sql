/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250722@Hughie
	Task: AutoPayout2 for Kabaddi [Redmine:#219400]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting WITH(ROWLOCK,UPDLOCK)
SET  AP_Group = 1
	,AP_Main_NumberProvider = 1
	,AP_Main_CheckList = '1,2,3,90,99'
WHERE Sporttype IN (47)