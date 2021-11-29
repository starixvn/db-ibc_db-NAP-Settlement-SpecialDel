/*<info serverAlias="DBTXN-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20211129@Kathy 
	Task: extend data type [Redmine:#165300]
	DB: DBTXN/bodb02
*/
USE bodb02
GO

ALTER TABLE SettlementBettypeResult ALTER COLUMN HomeValue VARCHAR(2000)
GO
ALTER TABLE SettlementBettypeResult ALTER COLUMN AwayValue VARCHAR(2000)
GO
