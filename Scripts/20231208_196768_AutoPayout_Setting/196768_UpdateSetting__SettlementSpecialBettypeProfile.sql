/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
UPDATE SettlementSpecialBettypeProfile
SET HasAwayValue = 1
WHERE SportType = 50
    AND ResourceID in ('00','9446','9447','9449','96151','94511')








