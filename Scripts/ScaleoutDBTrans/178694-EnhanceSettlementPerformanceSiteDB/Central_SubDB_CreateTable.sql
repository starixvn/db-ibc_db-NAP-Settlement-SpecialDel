/*<info serverAlias="DBCTG-bodb02,SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
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

