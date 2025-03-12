/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250313@Harley
	- 20250313@Harley: Support SOP and AutoPayout2 for Beach Volleyball [Redmine:#217843]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting 
SET IsAppliedSOP = 1
WHERE sporttype = 45
