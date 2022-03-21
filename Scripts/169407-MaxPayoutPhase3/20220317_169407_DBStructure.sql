/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220317@Max
	Task: [TVS] Support Max Payout & Max Turnover for Deposit - [Redmine: #169407]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[CustLimitBet_LIC](
	[Matchid] [int] NOT NULL,
	[CustID] [int] NOT NULL,
	[AccumTurnover] [money] NOT NULL,
	[AccumPayout] [money] NOT NULL,
	[EventTypeID] [tinyint] NOT NULL,
	[LastQueueID] [bigint] NOT NULL,
	[ModifiedDate] [datetime] NOT NULL,
 CONSTRAINT [PK_CustLimitBet_LIC_Matchid_CustID] PRIMARY KEY CLUSTERED 
(
	[Matchid] ASC,
	[CustID] ASC,
	[EventTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
) ON [winlimit_table]

GO

ALTER TABLE [dbo].[CustLimitBet_LIC] ADD  CONSTRAINT [DF_CustLimitBet_LIC_LastQueueID]  DEFAULT ((0)) FOR [LastQueueID]
GO

 /*------------HISTORY--------------*/
CREATE TABLE [dbo].[CustLimitBetHistory_LIC](
	[Matchid] [int] NOT NULL,
	[CustID] [int] NOT NULL,
	[Transid] [bigint] NOT NULL,
	[TurnoverAdjust] [money] NOT NULL,
	[PayoutAdjust] [money] NOT NULL,
	[EventTypeID] [tinyint] NOT NULL,
	[CreatedDate] [datetime] NOT NULL
) ON [winlimit_table]

GO

ALTER TABLE [dbo].[CustLimitBetHistory_LIC] ADD  CONSTRAINT [DF_CustLimitBetHistory_LIC_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO







