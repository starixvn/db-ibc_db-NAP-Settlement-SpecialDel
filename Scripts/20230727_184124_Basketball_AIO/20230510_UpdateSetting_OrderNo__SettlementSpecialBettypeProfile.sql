/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230727@Aries
	Task: Basketball AIO  [Redmine: #191381]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementSpecialBettypeProfile
SET GroupType = '1H',
	OrdNo = 3
WHERE SportType = 2 AND BetType = 648


GO
UPDATE SettlementSpecialBettypeProfile
SET OrdNo = 4
WHERE SportType = 2 AND BetType = 650  AND BetID = 803

GO
UPDATE SettlementSpecialBettypeProfile
SET OrdNo = 5
WHERE SportType = 2 AND BetType = 650  AND BetID = 804