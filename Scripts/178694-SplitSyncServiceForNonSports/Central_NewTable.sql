/*<info serverAlias="DBCTG-bodb02"></info>*/
USE [bodb02]
GO

CREATE TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd_History](
	[LogId] [bigint] NOT NULL,
	[SiteDBGroupId] [smallint] NULL,
	[LogDate] [datetime2](7) NULL
) ON [DATA]
GO

ALTER TABLE [dbo].[SiteDB_SettlementService_CalculationLog_3rd_History] ADD  CONSTRAINT [DF_SiteDB_SettlementService_CalculationLog_3rd_History_LogDate]  DEFAULT (sysdatetime()) FOR [LogDate]
GO


CREATE CLUSTERED INDEX [CIX_SiteDB_SettlementService_CalculationLog_3rd_History_LogDate] ON [dbo].[SiteDB_SettlementService_CalculationLog_3rd_History]
(
	[LogDate] ASC
) ON [DATA]
GO


CREATE NONCLUSTERED INDEX [IX_SiteDB_SettlementService_CalculationLog_3rd_History_LogIdSiteDBGroupId] ON [dbo].[SiteDB_SettlementService_CalculationLog_3rd_History]
(
	[LogId] ASC,
	[SiteDBGroupId] ASC
) ON [DATA]
GO
