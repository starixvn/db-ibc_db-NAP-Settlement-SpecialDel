/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220623@Max
	Task: Max Payout - Change (Credit) to support Bettrans_Running - [Redmine: #174304]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

/*----------------------MBC--------------------------*/
CREATE CLUSTERED INDEX [CIX_CustLimitBetHistory_MBC_MatchId_CustId_Transid_BRID] ON [dbo].[CustLimitBetHistory_MBC]
(
	[Matchid]	ASC,
	[CustID]	ASC,
	[Transid]	ASC,
	[BRID]		ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO
/*----------------------MBC--------------------------*/


/*----------------------789y--------------------------*/
CREATE CLUSTERED INDEX [CIX_CustLimitBetHistory_789_MatchId_CustId_Transid_BRID] ON [dbo].[CustLimitBetHistory_789]
(
	[Matchid]	ASC,
	[CustID]	ASC,
	[Transid]	ASC,
	[BRID]		ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO
/*----------------------789y--------------------------*/


/*----------------------LIC--------------------------*/
CREATE CLUSTERED INDEX [CIX_CustLimitBetHistory_LIC_MatchId_CustId_Transid_BRID] ON [dbo].[CustLimitBetHistory_LIC]
(
	[Matchid]	ASC,
	[CustID]	ASC,
	[Transid]	ASC,
	[BRID]		ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO
/*----------------------LIC--------------------------*/






