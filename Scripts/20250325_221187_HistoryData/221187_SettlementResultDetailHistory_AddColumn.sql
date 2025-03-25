/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250324@Aries
	Task: Enhance data history when updating events and results  [Redmine:#221187]
	DB: DBTP/bodb02
*/

USE bodb02
GO
ALTER TABLE dbo.SettlementResultDetailHistory ADD OldOtherInfo VARCHAR(50)
ALTER TABLE dbo.SettlementResultDetailHistory ADD NewOtherInfo VARCHAR(50)
ALTER TABLE dbo.SettlementResultDetailHistory ADD OldResultSetting TINYINT
ALTER TABLE dbo.SettlementResultDetailHistory ADD NewResultSetting TINYINT

