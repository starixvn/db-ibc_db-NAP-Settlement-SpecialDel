/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: 20240703@Aries
	Task: VS5 - Virtually Sports  [Redmine:#207309]
	DB: DBPRO/bodb02
*/
USE  bodb02
GO
UPDATE SettlementSpecialBettypeProfile 
SET OddsType = NULL
WHERE SportType IN (178,179)
    AND BetType IN (5306,5307)
    AND rId in (340,341,338,339)
