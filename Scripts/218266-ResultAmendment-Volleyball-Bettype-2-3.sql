﻿/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250327@Louisa
	Task:Integration - Result Amendment for Volleyball [Redmine:#218266]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
 
UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK,UPDLOCK)
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.refResourceIds', '0101,0102,0103,0104,0105')
WHERE SportType = 6 
	AND bettype IN (2,3)
