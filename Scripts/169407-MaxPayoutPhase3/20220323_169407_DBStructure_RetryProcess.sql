/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220317@Max
	Task: [TVS] Support Max Payout & Max Turnover for Deposit - [Redmine: #169407]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[CustLimitBet_QueueRetry](
	[TransId] [bigint] NOT NULL,
	[Sitetype] [tinyint] NOT NULL,
	[MainQueueId] [bigint] NOT NULL,
	[StatusId] [tinyint] NOT NULL,
	[Createddate] [datetime] NOT NULL,
	[Trycount] [tinyint] NOT NULL,
) ON [winlimit_table]

GO

ALTER TABLE [dbo].[CustLimitBet_QueueRetry] ADD  CONSTRAINT [DF_CustLimitBet_QueueRetry_TryCount]  DEFAULT ((0)) FOR [Trycount]
GO

ALTER TABLE [dbo].[CustLimitBet_QueueRetry] ADD  CONSTRAINT [DF_CustLimitBet_QueueRetry_CreatedDate]  DEFAULT (GETDATE()) FOR [Createddate]
GO

CREATE CLUSTERED INDEX [CIX_CustLimitBet_QueueRetry_MainQueueId_Sitetype] ON [dbo].[CustLimitBet_QueueRetry]
(
	[MainQueueId] ASC,
	[Sitetype] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO

CREATE NONCLUSTERED INDEX [IX_CustLimitBet_QueueRetry_StatusId] ON [dbo].[CustLimitBet_QueueRetry]
(
	[Statusid]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO








