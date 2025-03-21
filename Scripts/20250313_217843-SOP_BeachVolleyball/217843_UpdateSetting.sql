/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250319@Jane
	- 20250319@Jane: Support SOP and AutoPayout2 for Beach Volleyball [Redmine:#217843]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting WITH(ROWLOCK,UPDLOCK)
SET IsAppliedSOP = 1
	,Setting = 7
WHERE sporttype = 45
