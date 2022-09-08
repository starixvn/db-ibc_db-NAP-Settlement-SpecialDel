/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220721@Max
	Task: Max Payout - Change (Credit) to support Bettrans_Running - [Redmine: #174304]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

/*----------------------MBC--------------------------*/
ALTER TABLE [dbo].[CustLimitBetHistory_MBC] DROP CONSTRAINT [DF_CustLimitBetHistory_MBC_TransId]
GO

ALTER TABLE [dbo].[CustLimitBetHistory_MBC] DROP CONSTRAINT [DF_CustLimitBetHistory_MBC_BRID]
GO

ALTER TABLE [CustLimitBetHistory_MBC]
	DROP COLUMN [BRID];
GO

ALTER TABLE [CustLimitBetHistory_MBC]
	ALTER COLUMN [TransId] BIGINT NOT NULL;
GO
/*----------------------MBC--------------------------*/


/*----------------------789y--------------------------*/
ALTER TABLE [dbo].[CustLimitBetHistory_789] DROP CONSTRAINT [DF_CustLimitBetHistory_789_TransId]
GO

ALTER TABLE [dbo].[CustLimitBetHistory_789] DROP CONSTRAINT [DF_CustLimitBetHistory_789_BRID]
GO

ALTER TABLE [CustLimitBetHistory_789]
	DROP COLUMN [BRID];
GO

ALTER TABLE [CustLimitBetHistory_789]
	ALTER COLUMN [TransId] BIGINT NOT NULL;
GO
/*----------------------789y--------------------------*/


/*----------------------LIC--------------------------*/
ALTER TABLE [dbo].[CustLimitBetHistory_LIC] DROP CONSTRAINT [DF_CustLimitBetHistory_LIC_TransId]
GO

ALTER TABLE [dbo].[CustLimitBetHistory_LIC] DROP CONSTRAINT [DF_CustLimitBetHistory_LIC_BRID]
GO

ALTER TABLE [CustLimitBetHistory_LIC]
	DROP COLUMN [BRID];
GO

ALTER TABLE [CustLimitBetHistory_LIC]
	ALTER COLUMN [TransId] BIGINT NOT NULL;
GO
/*----------------------LIC--------------------------*/






