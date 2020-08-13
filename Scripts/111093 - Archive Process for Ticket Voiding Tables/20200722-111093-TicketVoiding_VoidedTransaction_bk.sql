/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_VoidedTransaction_bk](
	[TransId] [bigint] NOT NULL,
	[MessageId] [int] NOT NULL,
	[ReasonId] [int] NOT NULL,
	[MatchId] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[Id] [int] NOT NULL,
	[IssueTypeID] [tinyint] NULL,
	[SubIssueTypeID] [tinyint] NULL,
	[CustID] [int] NULL,

) ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_VoidedTransaction_bk] ADD  CONSTRAINT [DF_TicketVoiding_VoidedTransaction_bk_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE CLUSTERED INDEX [CIX_TicketVoiding_VoidedTransaction_bk_Transid] ON [dbo].[TicketVoiding_VoidedTransaction_bk]
(
	[TransId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_IssueTypeID_CreatedDate_CustID] ON [dbo].[TicketVoiding_VoidedTransaction_bk]
(
	[IssueTypeID] ASC,
	[CreatedDate] ASC,
	[CustID] ASC
)
INCLUDE([SubIssueTypeID],[ReasonId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO



