/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211112@Max
	Task: Max Payout Phase 2 - [Redmine: #159626]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

/*----------------------MBC--------------------------*/
DROP INDEX [IX_CustLimitBetHistory_MBC_MatchId_CustId_Transid] ON [dbo].[CustLimitBetHistory_MBC]

CREATE CLUSTERED INDEX [CIX_CustLimitBetHistory_MBC_MatchId_CustId_Transid] ON [dbo].[CustLimitBetHistory_MBC]
(
	[Matchid]	ASC,
	[CustID]	ASC,
	[Transid]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO
/*----------------------MBC--------------------------*/


/*----------------------789y--------------------------*/
DROP INDEX [IX_CustLimitBetHistory_789_MatchId_CustId_Transid] ON [dbo].[CustLimitBetHistory_789]

CREATE CLUSTERED INDEX [CIX_CustLimitBetHistory_789_MatchId_CustId_Transid] ON [dbo].[CustLimitBetHistory_789]
(
	[Matchid]	ASC,
	[CustID]	ASC,
	[Transid]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO
/*----------------------789y--------------------------*/


/*---------------------QUEUE--------------------------*/
CREATE NONCLUSTERED INDEX [IX_CustLimitBetQueue_StatusId] ON [dbo].[CustLimitBetQueue]
(
	[Statusid]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO






