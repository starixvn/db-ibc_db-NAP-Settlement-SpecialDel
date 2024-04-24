/*<info serverAlias="DBCTG-bodb02" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20240215@Kathy
	Task	  : create new table
	DB		  : DBCTG/bodb02
*/

USE [bodb02]
GO

IF OBJECT_ID('SiteDB_ParlaySettlementProcessing') IS NOT NULL
	DROP TABLE dbo.SiteDB_ParlaySettlementProcessing

CREATE TABLE [dbo].[SiteDB_ParlaySettlementProcessing](
	[Id] [bigint] IDENTITY(1,1),
	[SiteDBGroupId] [smallint] NOT NULL,
	[SessionId] [bigint] NULL,
	[MatchId] [int] NULL,
	[TableName] [varchar](128) NULL,
	[TransInfoBettransM] [varbinary](max) NULL,
	[TransInfoBetParlayResult] [varbinary](max) NULL,
	[TransInfoBettrans] [varbinary](max) NULL,
	[MessageType] [varchar](200) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL,
	[StatusId] [tinyint] NULL,
	[SiteDB_ParlaySettlementProcessingId] [bigint] NULL,
 CONSTRAINT [PK_SiteDB_ParlaySettlementProcessing] PRIMARY KEY NONCLUSTERED 
 (
	[Id] ASC
)ON [DATA] 
) ON [DATA] 
GO

ALTER TABLE [dbo].[SiteDB_ParlaySettlementProcessing] ADD CONSTRAINT DF_SiteDB_ParlaySettlementProcessing_StatusId DEFAULT ((0)) FOR [StatusId]
GO

CREATE CLUSTERED INDEX [CIX_SiteDB_ParlaySettlementProcessing_SessionId_SiteDBGroupId_MessageType] ON [dbo].[SiteDB_ParlaySettlementProcessing]
(
	[SessionId] ASC,
	[SiteDBGroupId] ASC,
	[MessageType] ASC
)ON [DATA]
GO


-----------------------------------------------------------
-----------------------------------------------------------
IF OBJECT_ID('SiteDB_ParlaySettlementLock') IS NOT NULL
	DROP TABLE dbo.SiteDB_ParlaySettlementLock

CREATE TABLE [dbo].[SiteDB_ParlaySettlementLock](
	[MatchId] [int] NULL,
	[SiteDBGroupId] [smallint] NULL,
	[SessionId] [bigint] NOT NULL,
	[CreatedTime] [datetime] NULL
) ON [DATA]
GO

ALTER TABLE [dbo].[SiteDB_ParlaySettlementLock] ADD  CONSTRAINT [DF_SiteDB_ParlaySettlementLock_CreatedTime]  DEFAULT (getdate()) FOR [CreatedTime]
GO

CREATE CLUSTERED INDEX [CIX_SiteDB_ParlaySettlementLock_SessionId_SiteDBGroupId] ON [dbo].[SiteDB_ParlaySettlementLock]
(
	[SessionId] ASC,
	[SiteDBGroupId] ASC
)ON [DATA]
GO
-----------------------------------------------------------
-----------------------------------------------------------