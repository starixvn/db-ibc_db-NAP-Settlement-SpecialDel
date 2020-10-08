/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20200922@Kathy
	Task: Add new column [Redmine:#138552] 
	DB: DBBAH/BODB02
	
*/

USE bodb02
GO
-- BalanceTrigger
ALTER TABLE dbo.BalanceTrigger ADD StatusId TINYINT
GO
ALTER TABLE dbo.BalanceTrigger ADD MatchId INT
GO
ALTER TABLE dbo.BalanceTrigger ADD SettlementType TINYINT CONSTRAINT DF_BalanceTrigger_SettlementType DEFAULT (0)
GO
ALTER TABLE dbo.BalanceTrigger ADD awinlost MONEY
GO
ALTER TABLE dbo.BalanceTrigger ADD mwinlost MONEY
GO
ALTER TABLE dbo.BalanceTrigger ADD swinlost MONEY
GO
ALTER TABLE dbo.BalanceTrigger ADD comm MONEY
GO
ALTER TABLE dbo.BalanceTrigger ADD acomm MONEY
GO
ALTER TABLE dbo.BalanceTrigger ADD scomm MONEY
GO
-- BalanceTrigger_ProcessData
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD StatusId TINYINT
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD MatchId INT
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD SettlementType TINYINT CONSTRAINT DF_BalanceTrigger_ProcessData_SettlementType  DEFAULT (0)
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD awinlost MONEY
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD mwinlost MONEY
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD swinlost MONEY
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD comm MONEY
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD acomm MONEY
GO
ALTER TABLE dbo.BalanceTrigger_ProcessData ADD scomm MONEY
GO

-- BalanceRecord
ALTER TABLE dbo.BalanceRecord ADD StatusId TINYINT
GO
ALTER TABLE dbo.BalanceRecord ADD MatchId INT
GO
ALTER TABLE dbo.BalanceRecord ADD SettlementType TINYINT CONSTRAINT DF_BalanceRecord_SettlementType DEFAULT (0)
GO
ALTER TABLE dbo.BalanceRecord ADD awinlost MONEY
GO
ALTER TABLE dbo.BalanceRecord ADD mwinlost MONEY
GO
ALTER TABLE dbo.BalanceRecord ADD swinlost MONEY
GO
ALTER TABLE dbo.BalanceRecord ADD comm MONEY
GO
ALTER TABLE dbo.BalanceRecord ADD acomm MONEY
GO
ALTER TABLE dbo.BalanceRecord ADD scomm MONEY
GO