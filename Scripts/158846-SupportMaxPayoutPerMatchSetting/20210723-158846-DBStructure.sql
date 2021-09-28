/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20210723@Max
	Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	DB: DBTRANS-bodb02
*/

USE bodb02
GO

/*----------------------MBC--------------------------*/
CREATE TABLE [dbo].[CustLimitBet_MBC](
	[Matchid]		INT			NOT NULL,
	[CustID]		INT			NOT NULL,
	[AccumTurnover]	MONEY		NOT NULL,
	[AccumPayout]	MONEY		NOT NULL,
	[EventTypeID]	TINYINT		NOT NULL,
	[LastQueueID]	BIGINT		NOT NULL,
	[ModifiedDate]	DATETIME	NOT NULL,
CONSTRAINT [PK_CustLimitBet_MBC_Matchid_CustID] PRIMARY KEY CLUSTERED 
(
	[Matchid] ASC,
	[CustID] ASC,
	[EventTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
) ON [winlimit_table]
GO
ALTER TABLE [dbo].[CustLimitBet_MBC] ADD  CONSTRAINT [DF_CustLimitBet_MBC_LastQueueID]  DEFAULT (0) FOR [LastQueueID]
GO

CREATE TABLE [dbo].[CustLimitBetHistory_MBC](
	[Matchid]			INT			NOT NULL,
	[CustID]			INT			NOT NULL,
	[Transid]			BIGINT		NOT NULL,
	[TurnoverAdjust]	MONEY		NOT NULL,
	[PayoutAdjust]		MONEY		NOT NULL,
	[EventTypeID]		TINYINT		NOT NULL,
	[CreatedDate]		DATETIME	NOT NULL,
) ON [winlimit_table]
CREATE NONCLUSTERED INDEX [IX_CustLimitBetHistory_MBC_MatchId_CustId_Transid] ON [dbo].[CustLimitBetHistory_MBC]
(
	[Matchid]	ASC,
	[CustID]	ASC,
	[Transid]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO
ALTER TABLE [dbo].[CustLimitBetHistory_MBC] ADD  CONSTRAINT [DF_CustLimitBetHistory_MBC_CreatedDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO
/*----------------------MBC--------------------------*/

/*----------------------789y--------------------------*/
CREATE TABLE [dbo].[CustLimitBet_789](
	[Matchid]		INT			NOT NULL,
	[CustID]		INT			NOT NULL,
	[AccumTurnover]	MONEY		NOT NULL,
	[AccumPayout]	MONEY		NOT NULL,
	[EventTypeID]	TINYINT		NOT NULL,
	[LastQueueID]	BIGINT		NOT NULL,
	[ModifiedDate]	DATETIME	NOT NULL,
CONSTRAINT [PK_CustLimitBet_789_Matchid_CustID] PRIMARY KEY CLUSTERED 
(
	[Matchid] ASC,
	[CustID] ASC,
	[EventTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
) ON [winlimit_table]
GO
ALTER TABLE [dbo].[CustLimitBet_789] ADD  CONSTRAINT [DF_CustLimitBet_789_LastQueueID]  DEFAULT (0) FOR [LastQueueID]
GO

CREATE TABLE [dbo].[CustLimitBetHistory_789](
	[Matchid]			INT			NOT NULL,
	[CustID]			INT			NOT NULL,
	[Transid]			BIGINT		NOT NULL,
	[TurnoverAdjust]	MONEY		NOT NULL,
	[PayoutAdjust]		MONEY		NOT NULL,
	[EventTypeID]		TINYINT		NOT NULL,
	[CreatedDate]		DATETIME	NOT NULL,
) ON [winlimit_table]
CREATE NONCLUSTERED INDEX [IX_CustLimitBetHistory_789_MatchId_CustId_Transid] ON [dbo].[CustLimitBetHistory_789]
(
	[Matchid]	ASC,
	[CustID]	ASC,
	[Transid]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO
ALTER TABLE [dbo].[CustLimitBetHistory_789] ADD  CONSTRAINT [DF_CustLimitBetHistory_789_CreatedDate]  DEFAULT (GETDATE()) FOR [CreatedDate]
GO
/*----------------------789y--------------------------*/

/*---------------------QUEUE--------------------------*/
CREATE TABLE [dbo].[CustLimitBetQueue](
	[QueueID]		BIGINT			IDENTITY(1,1) NOT NULL,
	[Matchid]		INT				NOT NULL,
	[CustID]		INT				NULL,
	[EventTypeID]	TINYINT			NOT NULL,
	[Transids]		VARCHAR(MAX)	NOT NULL,
	[ActionID]		TINYINT			NOT NULL,
	[Statusid]		TINYINT			NOT NULL,
	[CreatedDate]	DATETIME		NOT NULL,
	[ExecTime]		DATETIME		NULL,
	[Duration]		INT				NULL,
	[ErrMsg]		VARCHAR(300)	NULL
CONSTRAINT [PK_CustLimitBetQueue_MBC_QueueID] PRIMARY KEY CLUSTERED 
(
	[QueueID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
) ON [winlimit_table] TEXTIMAGE_ON [winlimit_table]
GO
CREATE NONCLUSTERED INDEX [IX_CustLimitBetQueue_MatchId_CustId] ON [dbo].[CustLimitBetQueue]
(
	[Matchid]	ASC,
	[CustID]	ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [winlimit_table]
GO






