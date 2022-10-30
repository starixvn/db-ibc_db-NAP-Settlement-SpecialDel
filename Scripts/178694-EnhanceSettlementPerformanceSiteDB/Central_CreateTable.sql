/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO

CREATE TABLE [dbo].[SiteDB_SettlementProcessing](
	[Id] [bigint] IDENTITY(1,1) NOT NULL,
	[SiteDBGroupId] [smallint] NOT NULL,
	[SessionId] [bigint] NOT NULL,
	[MessageType] [varchar](200) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL,
	[TransInfo] [varchar](max) NULL,
	[StatusId] [tinyint] NULL,
 CONSTRAINT [PK_SiteDB_SettlementProcessing] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
) ON [DATA]
) ON [DATA]
GO

ALTER TABLE [dbo].[SiteDB_SettlementProcessing] ADD  CONSTRAINT [DF_SiteDB_SettlementProcessing_StatusId]  DEFAULT ((0)) FOR [StatusId]
GO


--drop table [SiteDB_SettlementProcessing]
