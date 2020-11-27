/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20201119@Kathy
	Task: Add new column [Redmine:#142346] 
	DB: DBBAH/BODB02
	
*/

USE bodb02
GO
-- BalanceTrigger
ALTER TABLE dbo.BalanceTrigger ADD modds SMALLMONEY
GO

-- BalanceTrigger_ProcessData
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD modds SMALLMONEY
GO

-- BalanceRecord
ALTER TABLE dbo.BalanceRecord ADD modds SMALLMONEY
GO