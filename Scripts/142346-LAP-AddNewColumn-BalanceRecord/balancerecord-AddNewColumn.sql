/*<info serverAlias="DBBAH-balancerecord" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20201119@Kathy
	Task: Add new column [Redmine:#142346] 
	DB: DBBAH/balancerecord
	
*/
USE BalanceRecord
GO
ALTER TABLE dbo.BalanceRecord_bk ADD modds SMALLMONEY
GO