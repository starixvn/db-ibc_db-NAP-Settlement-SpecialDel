/*<info serverAlias="DBTXN-bodb02,DBPRO-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20230510@Aries
	Task: Apply Settle Determined for Basketball [Redmine: #184124]
	DB: DBTXN/bodb02, DBPRO/bodb02
*/
USE bodb02
GO
ALTER TABLE SettlementSpecialBettypeProfile ALTER COLUMN SDTResourceId  VARCHAR(20); 
GO
ALTER TABLE SettlementSpecialBettypeProfile ALTER COLUMN IsSDT  BIT; 