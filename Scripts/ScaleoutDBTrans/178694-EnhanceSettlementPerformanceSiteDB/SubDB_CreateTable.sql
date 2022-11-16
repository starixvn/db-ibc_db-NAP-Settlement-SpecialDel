/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO

CREATE TABLE [dbo].[SiteDB_SettlementLock](
	[MatchId] [int] NULL,
	[SiteDBGroupId] [smallint] NULL,
	[SessionId] [bigint] NOT NULL,
	[CreatedTime] [datetime] NULL
) ON [DATA]
GO

ALTER TABLE [dbo].[SiteDB_SettlementLock] ADD  CONSTRAINT [DF_SiteDB_SettlementLock_CreatedTime]  DEFAULT (getdate()) FOR [CreatedTime]
GO

CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementLock_SessionId_SiteDBGroupId] ON [dbo].[SiteDB_SettlementLock]
(
	[SessionId] ASC,
	[SiteDBGroupId] ASC
)ON [DATA]
GO

CREATE TABLE [dbo].[SiteDB_SettlementProcessing](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[SiteDBGroupId] [smallint] NOT NULL,
	[SessionId] [bigint] NOT NULL,
	[MessageType] [varchar](200) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL,
	[TransInfo] [varbinary](max) NULL,
	[StatusId] [tinyint] NULL,
 CONSTRAINT [PK_SiteDB_SettlementProcessing] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
) ON [DATA]
) ON [DATA]
GO

ALTER TABLE [dbo].[SiteDB_SettlementProcessing] ADD  CONSTRAINT [DF_SiteDB_SettlementProcessing_StatusId]  DEFAULT ((0)) FOR [StatusId]
GO

CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementProcessing_SessionId_SiteDBGroupId_MessageType] ON [dbo].[SiteDB_SettlementProcessing]
(
	[SessionId] ASC,
	[SiteDBGroupId] ASC,
	[MessageType] ASC
) ON [DATA]
GO


ALTER TABLE dbo.SSB_SettlementLogs 
	ADD SiteDBGroupId SMALLINT CONSTRAINT [DF_SSB_SettlementLogs_SiteDBGroupId]  DEFAULT (0) 