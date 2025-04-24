﻿/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250327@Louisa
	Task:Integration - Result Amendment for Tennis [Redmine:#220621]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
 
UPDATE SettlementSpecialBettypeProfile WITH(ROWLOCK,UPDLOCK)
SET APSetting = JSON_MODIFY(ISNULL(APSetting,'{}'), '$.refResourceIds', '01,02,03,04,05,00')
WHERE SportType = 5
	AND bettype = 153  