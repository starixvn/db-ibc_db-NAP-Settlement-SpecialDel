/*<info serverAlias="DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 2024111@Louisa
	Task: Refund Determined for Baseball [Redmine: #212365]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO 
UPDATE sp
SET sp.SDTpfId =  8809
FROM SettlementSpecialBettypeProfile sp  WITH (ROWLOCK,UPDLOCK)
WHERE sp.SportType = 8   
	AND sp.bettype IN (8803,8809)


	 

GO

