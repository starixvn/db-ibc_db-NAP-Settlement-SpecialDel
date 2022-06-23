/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220623@Max
	Task: Max Payout - Change (Credit) to support Bettrans_Running - [Redmine: #174304]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

/*----------------------MBC--------------------------*/
ALTER TABLE [CustLimitBetHistory_MBC]
	ADD [BRID] BIGINT NULL;

ALTER TABLE [CustLimitBetHistory_MBC]
	ALTER COLUMN [TransId] BIGINT NULL;

ALTER TABLE [dbo].[CustLimitBetHistory_MBC] ADD  CONSTRAINT [DF_CustLimitBetHistory_MBC_TransId]  DEFAULT (0) FOR [TransId]
GO

ALTER TABLE [dbo].[CustLimitBetHistory_MBC] ADD  CONSTRAINT [DF_CustLimitBetHistory_MBC_BRID]  DEFAULT (0) FOR [BRID]
GO
/*----------------------MBC--------------------------*/


/*----------------------789y--------------------------*/
ALTER TABLE [CustLimitBetHistory_789]
	ADD [BRID] BIGINT NULL;

ALTER TABLE [CustLimitBetHistory_789]
	ALTER COLUMN [TransId] BIGINT NULL;

ALTER TABLE [dbo].[CustLimitBetHistory_789] ADD  CONSTRAINT [DF_CustLimitBetHistory_789_TransId]  DEFAULT (0) FOR [TransId]
GO

ALTER TABLE [dbo].[CustLimitBetHistory_789] ADD  CONSTRAINT [DF_CustLimitBetHistory_789_BRID]  DEFAULT (0) FOR [BRID]
GO
/*----------------------789y--------------------------*/


/*----------------------LIC--------------------------*/
ALTER TABLE [CustLimitBetHistory_LIC]
	ADD [BRID] BIGINT NULL;

ALTER TABLE [CustLimitBetHistory_LIC]
	ALTER COLUMN [TransId] BIGINT NULL;

ALTER TABLE [dbo].[CustLimitBetHistory_LIC] ADD  CONSTRAINT [DF_CustLimitBetHistory_LIC_TransId]  DEFAULT (0) FOR [TransId]
GO

ALTER TABLE [dbo].[CustLimitBetHistory_LIC] ADD  CONSTRAINT [DF_CustLimitBetHistory_LIC_BRID]  DEFAULT (0) FOR [BRID]
GO
/*----------------------LIC--------------------------*/






