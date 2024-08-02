/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: 20240703@Aries
	Task: VS5 - Virtually Sports  [Redmine:#207309]
	DB: DBPRO/bodb02
*/
USE  bodb02
GO
INSERT INTO SettlementSpecialBettypeProfile(pfId,BetType,Sporttype,BetId,ResourceID,SettleType,GroupType,OddsType,Is3x30)
SELECT 5 AS pfId, 11050 AS BetType, 147 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 24 AS pfId, 11051 AS BetType, 147 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 5 AS pfId, 11052 AS BetType, 147 AS Sporttype, 0 AS BetId, '01' AS ResourceID,'MNL' AS SettleType, 'HT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 644 AS pfId, 11053 AS BetType, 147 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 1 AS pfId, 11054 AS BetType, 147 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 3 AS pfId, 11055 AS BetType, 147 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30
