/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 2024111@Aries
	Task: Fix an issue which is wrong settlement due to the lack of consistency when calculating Innnings [Redmine:#213767]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO

ALTER TABLE SettlementSpecialBettypeProfile ADD APSetting VARCHAR(MAX);
GO

/****************************************************/
UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101')
WHERE SportType = 8 and ResourceID = '0102'

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101,0102')
WHERE SportType = 8 and ResourceID = '0103'

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101,0102,0103')
WHERE SportType = 8 and ResourceID = '0104'

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101,0102,0103,0104')
WHERE SportType = 8 and ResourceID = '0105'

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101,0102,0103,0104,0105')
WHERE SportType = 8 and ResourceID = '0106'

UPDATE SettlementSpecialBettypeProfile
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.relatedCalResources', '0101,0102,0103,0104,0105,0106')
WHERE SportType = 8 and ResourceID = '0107'
GO

/****************************************************/
UPDATE SettlementResultTableSetting
SET  AP_Main_CheckList = '1,2,3,4,92,97,99'
WHERE Sporttype = 8
