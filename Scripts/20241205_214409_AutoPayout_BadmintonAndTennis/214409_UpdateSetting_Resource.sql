/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241111@Aries
	Task: Support AutoPayout2 for Volleyball [Redmine:#214409]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101')
WHERE SportType = 9 and ResourceID like '71201%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0102')
WHERE SportType = 9 and ResourceID like '71202%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0103')
WHERE SportType = 9 and ResourceID like '71203%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0104')
WHERE SportType = 9 and ResourceID like '71204%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0105')
WHERE SportType = 9 and ResourceID like '71205%'


----------------------------------------------------------------

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101')
WHERE SportType = 9 and ResourceID like '71301%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0102')
WHERE SportType = 9 and ResourceID like '71302%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0103')
WHERE SportType = 9 and ResourceID like '71303%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0104')
WHERE SportType = 9 and ResourceID like '71304%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0105')
WHERE SportType = 9 and ResourceID like '71305%'


