/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_VoidingHistory_bk](
	[VoidingHistoryId] [int] NOT NULL,
	[RequestId] [int] NOT NULL,
	[MessageId] [int] NULL,
	[StatusId] [tinyint] NULL,
	[ReasonId] [int] NULL,
	[UserId] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[ModifiedDate] [datetime] NULL,
	[TransIds] [varchar](max) NULL,

) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_VoidingHistory_bk] ADD  CONSTRAINT [PK_TicketVoiding_VoidingHistory_bk_VoidingHistoryId] PRIMARY KEY NONCLUSTERED 
(
	[VoidingHistoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO


ALTER TABLE [dbo].[TicketVoiding_VoidingHistory_bk] ADD  CONSTRAINT [DF_TicketVoiding_VoidingHistory_bk_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

ALTER TABLE [dbo].[TicketVoiding_VoidingHistory_bk] ADD  CONSTRAINT [DF_TicketVoiding_VoidingHistory_bk_ModifiedDate]  DEFAULT (getdate()) FOR [ModifiedDate]
GO

CREATE CLUSTERED INDEX [CIX_TicketVoiding_VoidingHistory_bk_RequestId] ON [dbo].[TicketVoiding_VoidingHistory_bk]
(
	[RequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [ix_reasonid] ON [dbo].[TicketVoiding_VoidingHistory_bk]
(
	[ReasonId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_VoidingHistory_CreatedDate] ON [dbo].[TicketVoiding_VoidingHistory_bk]
(
	[CreatedDate] ASC
)
INCLUDE([MessageId],[StatusId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO


