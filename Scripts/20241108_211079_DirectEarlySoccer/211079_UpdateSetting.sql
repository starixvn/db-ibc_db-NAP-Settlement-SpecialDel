/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241028@Aries
	Task: Direct payout for early soccer [Redmine:#211079]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38101,38201')
WHERE SportType = 1 AND ResourceID = '38301'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38102,38202')
WHERE SportType = 1 AND ResourceID = '38302'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38103,38203')
WHERE SportType = 1 AND ResourceID = '38303'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38104,38204')
WHERE SportType = 1 AND ResourceID = '38304'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38105,38205')
WHERE SportType = 1 AND ResourceID = '38305'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38101,38201')
WHERE SportType = 1 AND ResourceID = '38501'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38102,38202')
WHERE SportType = 1 AND ResourceID = '38502'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38103,38203')
WHERE SportType = 1 AND ResourceID = '38503'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38104,38204')
WHERE SportType = 1 AND ResourceID = '38504'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38105,38205')
WHERE SportType = 1 AND ResourceID = '38505'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38101,38201')
WHERE SportType = 1 AND ResourceID = '38401'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38102,38202')
WHERE SportType = 1 AND ResourceID = '38402'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38103,38203')
WHERE SportType = 1 AND ResourceID = '38403'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38104,38204')
WHERE SportType = 1 AND ResourceID = '38404'
GO
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '38105,38205')
WHERE SportType = 1 AND ResourceID = '38405'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedSettResources', '38101,38102,38103,38104,38105,38201,38202,38203,38204,38205')
WHERE SportType = 1 AND ResourceID IN ('393','376','391')


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedSettResources', '38101,38102,38103,38104,38105')
WHERE SportType = 1 AND ResourceID IN ('387','386')