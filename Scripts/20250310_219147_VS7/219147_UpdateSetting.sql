/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
	Created by: 20250310@Aries
	Task: [Settlement] - Integration - Virtual Sports 7 - Kiron [Redmine:#219147]
	DB: DBPRO/bodb02

	Revisions:
		- 20240918@Aries: Created  [Redmine:#219147]

	Param's Explanation:
		
*/
USE bodb02
GO
INSERT INTO SettlementSpecialBettypeProfile(pfId,BetType,Sporttype,BetId,ResourceID,SettleType,GroupType,OddsType,Is3x30)
SELECT 2770 AS pfId, 15500 AS BetType, 125 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 2771 AS pfId, 15501 AS BetType, 125 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 2770 AS pfId, 15500 AS BetType, 126 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 2771 AS pfId, 15501 AS BetType, 126 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL
SELECT 2770 AS pfId, 15500 AS BetType, 127 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 2771 AS pfId, 15501 AS BetType, 127 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 


