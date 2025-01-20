/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20250117@Louisa
	Task: VS6-Virtual Basketball [Redmine: #216840]
	DB: DBPRO/bodb02
*/

USE bodb02


UPDATE sp
SET OddsType = 1
FROM SettlementSpecialBettypeProfile sp WITH(ROWLOCK, UPDLOCK)
WHERE sp.SportType = 134


 
 