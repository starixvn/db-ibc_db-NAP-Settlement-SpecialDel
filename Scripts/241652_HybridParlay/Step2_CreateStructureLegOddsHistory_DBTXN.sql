/*<info serverAlias="DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/    
/*	
	Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBCTG-bodb02,DBSIC-bodb02,DBSID-bodb02
	
	Revisions: 
		- 20251027@Max: Create table [Redmine: #241652]
*/

USE [bodb02]
GO

/****** Object:  Table [dbo].[BetBuilderLegOddsHistory]    Script Date: 10/28/2025 4:29:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BetBuilderLegOddsHistory](
	[MatchID] [int] NOT NULL,
	[RefNo] [bigint] NOT NULL,
	[TransId] [bigint] NOT NULL,
	[Odds] [smallmoney] NOT NULL,
	[CreatedDate] [datetime2] NOT NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[BetBuilderLegOddsHistory] ADD  CONSTRAINT [DF_BetBuilderLegOddsHistory_CreatedDate]  DEFAULT (sysdatetime()) FOR [CreatedDate]
GO

CREATE CLUSTERED INDEX [CIX_BetBuilderLegOddsHistory_CreatedDate] ON [dbo].[BetBuilderLegOddsHistory]
(
	[CreatedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO


/****** Object:  Index [BetBuilderHybridParlayLog]    Script Date: 10/28/2025 4:31:52 PM ******/
CREATE NONCLUSTERED INDEX [IX_BetBuilderLegOddsHistory_MatchID] ON [dbo].[BetBuilderLegOddsHistory]
(
	[MatchID] ASC,
	[RefNo] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO





