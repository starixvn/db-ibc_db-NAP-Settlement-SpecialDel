/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
	Created by: 20240918@Aries
	Task: Betradar VS - Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing [Redmine:#210875]
	DB: DBPRO/bodb02

	Revisions:
		- 20240918@Aries: Created  [Redmine:#210875]

	Param's Explanation:
		
*/
USE bodb02
GO
INSERT INTO SettlementSpecialBettypeProfile(pfId,BetType,Sporttype,BetId,ResourceID,SettleType,GroupType,OddsType,Is3x30)
SELECT 2770 AS pfId, 2770 AS BetType, 177 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 2771 AS pfId, 2771 AS BetType, 177 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 2770 AS pfId, 2770 AS BetType, 198 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 UNION ALL 
SELECT 2771 AS pfId, 2771 AS BetType, 198 AS Sporttype, 0 AS BetId, '00' AS ResourceID,'MNL' AS SettleType, 'FT' AS GroupType,1 AS OddsType, 0 AS Is3x30 