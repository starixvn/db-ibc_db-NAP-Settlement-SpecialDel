/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20250318@Aries
	Task: Sportsbook � SOP � Soccer � Phase 2 [Redmine: #220444]
	DB: DBPRO/bodb02
*/
USE bodb02

UPDATE  dbo.SettlementResultTableSetting 
SET IsAppliedSOP = 1
WHERE  Sporttype = 0