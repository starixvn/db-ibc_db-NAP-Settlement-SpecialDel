/*<info serverAlias="DBBAH-balancerecord" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20200922@Kathy
	Task: Add new column [Redmine:#138552] 
	DB: DBBAH/balancerecord
	
*/
USE BalanceRecord
GO
ALTER TABLE dbo.BalanceRecord_bk ADD StatusId TINYINT
GO
ALTER TABLE dbo.BalanceRecord_bk ADD MatchId INT
GO
ALTER TABLE dbo.BalanceRecord_bk ADD SettlementType TINYINT CONSTRAINT DF_BalanceRecord_bk_SettlementType DEFAULT (0)
GO
ALTER TABLE dbo.BalanceRecord_bk ADD awinlost MONEY
GO
ALTER TABLE dbo.BalanceRecord_bk ADD mwinlost MONEY
GO
ALTER TABLE dbo.BalanceRecord_bk ADD swinlost MONEY
GO
ALTER TABLE dbo.BalanceRecord_bk ADD comm MONEY
GO
ALTER TABLE dbo.BalanceRecord_bk ADD acomm MONEY
GO
ALTER TABLE dbo.BalanceRecord_bk ADD scomm MONEY
GO
