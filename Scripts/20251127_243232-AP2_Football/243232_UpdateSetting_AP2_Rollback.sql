/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20251127@Hughie
	Task: Support AutoPayout2 for Football [Redmine:#243232]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting WITH(ROWLOCK,UPDLOCK)
SET  AP_Group = NULL
WHERE Sporttype = 3