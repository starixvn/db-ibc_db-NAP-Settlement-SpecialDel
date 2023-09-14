/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230814@Aries
	Task: Apply Full SOP for Beach Vollleyball [Redmine: #193553]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
/************************Add setting Cal SDT**************************/
 UPDATE SettlementResultTableSetting
 SET IsAppliedSOP = 1
 WHERE Sporttype = 45