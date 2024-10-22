/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241002@Aries
	Task: Support a tool to add leagues for Direct Payout [Redmine:#211265]
	DB: DBPRO-bodb02

	Revision:
		- 20241002@Aries: Support a tool to add leagues for Direct Payout [Redmine:#211265]

*/


USE bodb02
GO
CREATE NONCLUSTERED INDEX IX_SettlementSetting_AutoType ON dbo.SettlementSetting (AutoType ASC)


	