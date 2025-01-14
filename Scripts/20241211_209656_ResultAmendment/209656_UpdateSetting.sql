/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241206@Aries
	Task:Integration - Result Amendment for Basketball and eSports [Redmine:#209656]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.refResourceIds', 'Q1,Q2,01')
WHERE SportType = 2 AND bettype IN (8,403,404,633)

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.refResourceIds', 'Q3,Q4,00')
WHERE SportType = 2 AND bettype IN (634)

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.refResourceIds', 'Q1,Q2,Q3,Q4,00')
WHERE SportType = 2 AND bettype IN (3,401,402,603,632,635,636,637,638, 639,640,641,642,643,644)

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.refResourceIds', 'Q1,Q2,01,Q3,Q4,00')
WHERE SportType = 2 AND bettype IN (645,646)

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.refResourceIds', 'Q3,Q4,00')
WHERE SportType = 2 AND bettype IN (624,625,626,649)
