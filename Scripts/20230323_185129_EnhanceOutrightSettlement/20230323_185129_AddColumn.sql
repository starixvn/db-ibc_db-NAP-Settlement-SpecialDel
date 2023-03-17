/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230323@Aries
	Task: Enhance Outright Settlement as User Feedback [Redmine: #185129]
	DB: DBPRO/bodb02
*/


USE bodb02
GO
ALTER TABLE dbo.SettlementSetting ADD DeadHeat BIT
