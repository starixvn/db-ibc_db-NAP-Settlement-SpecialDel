/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220721@Max
	Task: Max Payout - Change (Credit) to support Bettrans_Running - [Redmine: #174304]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

/*----------------------MBC--------------------------*/
DROP INDEX [CIX_CustLimitBetHistory_MBC] ON [dbo].[CustLimitBetHistory_MBC]
GO
/*----------------------MBC--------------------------*/


/*----------------------789y--------------------------*/
DROP INDEX [CIX_CustLimitBetHistory_789] ON [dbo].[CustLimitBetHistory_789]
GO
/*----------------------789y--------------------------*/


/*----------------------LIC--------------------------*/
DROP INDEX [CIX_CustLimitBetHistory_LIC] ON [dbo].[CustLimitBetHistory_LIC]
GO
/*----------------------LIC--------------------------*/






