/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/

USE [bodb02]
GO
/*  Creator: 20210514@Kathy
	Task: Initial data for job
	DB: DBTXN/BODB02

*/

IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.SystemSettings WITH(NOLOCK) WHERE VName = 'SingleSettlementJob')
	INSERT INTO dbo.SystemSettings (VName, VValue) VALUES ('SingleSettlementJob', '0')

GO
