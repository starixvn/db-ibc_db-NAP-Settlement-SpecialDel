/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20241111@Aries
	Task: Support AutoPayout2 for Volleyball [Redmine:#213198]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO


--ALTER TABLE SettlementSpecialBettypeProfile ADD APSetting VARCHAR(MAX);
GO
------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101')
WHERE SportType = 6 and ResourceID like '390301%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0102')
WHERE SportType = 6 and ResourceID like '390302%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0103')
WHERE SportType = 6 and ResourceID like '390303%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0104')
WHERE SportType = 6 and ResourceID like '390304%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0105')
WHERE SportType = 6 and ResourceID like '390305%'



-------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101')
WHERE SportType = 6 and ResourceID like '390901%'
------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0102')
WHERE SportType = 6 and ResourceID like '390902%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0103')
WHERE SportType = 6 and ResourceID like '390903%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0104')
WHERE SportType = 6 and ResourceID like '390904%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0105')
WHERE SportType = 6 and ResourceID like '390905%'

-------------

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101')
WHERE SportType = 6 and ResourceID like '391501%'

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0102')
WHERE SportType = 6 and ResourceID like '391502%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0103')
WHERE SportType = 6 and ResourceID like '391503%'

------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0104')
WHERE SportType = 6 and ResourceID like '391504%'


------------------------
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0105')
WHERE SportType = 6 and ResourceID like '391505%'