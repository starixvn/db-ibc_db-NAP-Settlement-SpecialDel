/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*  Created: 20220315@Kathy
	Task: add new column [Redmine:#166072 ]
	DB: DBTXN-bodb02
*/
ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD SDTpfId SMALLINT
GO
ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD Is3x30 BIT
GO
ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD SDTResourceId VARCHAR(20)
GO
ALTER TABLE dbo.SettlementSpecialBettypeProfile ADD IsSDT BIT