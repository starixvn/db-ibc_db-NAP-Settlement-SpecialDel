/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240603@Aries
	- 20240604@Aries: Support calculate interval child-matches for Table Tennis (SOP) [Redmine:#202100]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementResultTableSetting 
SET  ResultTable = 2
    ,IsAppliedSOP = 1
	,Setting = 7
WHERE sporttype = 18
