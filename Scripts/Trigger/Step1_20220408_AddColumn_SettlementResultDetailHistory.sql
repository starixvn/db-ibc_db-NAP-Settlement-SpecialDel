/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20220408@Louisa
	Task: Add new column  [Redmine:#170548]
	DB: DBTP/bodb02
*/

USE bodb02
GO

ALTER TABLE dbo.SettlementResultDetailHistory ADD OldResultStatusID TINYINT
GO

ALTER TABLE dbo.SettlementResultDetailHistory ADD NewResultStatusID TINYINT
GO

ALTER TABLE dbo.SettlementResultDetailHistory ADD  OldSettlementStatusID TINYINT
GO

ALTER TABLE dbo.SettlementResultDetailHistory ADD  NewSettlementStatusID TINYINT
GO