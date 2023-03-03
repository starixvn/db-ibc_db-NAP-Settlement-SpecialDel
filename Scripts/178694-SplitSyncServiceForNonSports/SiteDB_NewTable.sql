/*<info serverAlias="DBSIG-bodb02"></info>*/
USE [bodb02]
GO
-- SiteDB_SettlementService_CalculationLog_3rd
CREATE TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd](
	[LogId] [bigint] IDENTITY(1,1) NOT NULL,
	[SystemName] [varchar](50) NULL,
	[FunctionName] [varchar](50) NULL,
	[TableName] [varchar](128) NULL,
	[Action] [varchar](1) NULL,
	[MatchId] [int] NULL,
	[TransInfoJson] [varbinary](max) NULL,
	[LogDate] [datetime2](7) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL,
	[EventTable] [tinyint] NULL
) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_3rd_Action]  DEFAULT ('U') FOR [Action]
GO

ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_3rd_MatchId]  DEFAULT ((0)) FOR [MatchId]
GO

ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_3rd_LogDate]  DEFAULT (sysdatetime()) FOR [LogDate]
GO

CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementService_CalculationLog_3rd] ON [dbo].[SiteDB_SettlementService_CalculationLog_3rd]
(
	[LogId] ASC
) ON [DATA]
GO


CREATE NONCLUSTERED INDEX [IX_SiteDB_SettlementService_CalculationLog_3rd_LogDate] ON [dbo].[SiteDB_SettlementService_CalculationLog_3rd]
(
	[LogDate] ASC
) ON [DATA]
GO



--- SiteDB_SettlementService_LastLog_3rd

CREATE TABLE [dbo].[SiteDB_SettlementService_LastLog_3rd](
	[LogId] [bigint] NULL,
	[StatusId] [tinyint] NULL,
	[Starttime] [datetime2](7) NULL,
	[Endtime] [datetime2](7) NULL
) ON [DATA]
GO

CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementService_LastLog_3rd] ON [dbo].[SiteDB_SettlementService_LastLog_3rd]
(
	[LogId] ASC
) ON [DATA]
GO
