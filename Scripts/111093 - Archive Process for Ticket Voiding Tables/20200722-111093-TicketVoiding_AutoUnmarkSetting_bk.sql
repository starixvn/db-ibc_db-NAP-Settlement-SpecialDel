/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_AutoUnmarkSetting_bk](
	[ID] [int] NOT NULL,
	[Matchid] [int] NULL,
	[Bettype] [smallint] NULL,
	[IsConfirm] [bit] NULL,
	[CreatedDate] [datetime] NULL,
	[UserId] [int] NULL,
	[MarkedBy] [int] NULL,
	[betid] [bigint] NULL,
) ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_AutoUnmarkSetting_bk] ADD  CONSTRAINT [DF_TicketVoiding_AutoUnmarkSetting_bk_IsConfirm]  DEFAULT ((0)) FOR [IsConfirm]
GO

ALTER TABLE [dbo].[TicketVoiding_AutoUnmarkSetting_bk] ADD  CONSTRAINT [DF_TicketVoiding_AutoUnmarkSetting_bk_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE CLUSTERED INDEX [CIX_TicketVoiding_AutoUnmarkSetting_bk_Matchid_Bettype] ON [dbo].[TicketVoiding_AutoUnmarkSetting_bk]
(
	[Matchid] ASC,
	[Bettype] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_AutoUnmarkSetting_bk_CreatedDate] ON [dbo].[TicketVoiding_AutoUnmarkSetting_bk]
(
	[CreatedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO



