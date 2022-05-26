/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : 20220413@Kathy
	Task	: Add new column [Redmine:#170551]

*/
USE [bodb02]
GO
ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD DeterminedType TINYINT
GO
