/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/    
/*	
	Created by: Max
	Date 20251027
	Task: [Settlement] - Integration - Jacktime - Basketball Main Bettype Hybrid Parlay [Redmine: #241652]
	DB: DBCTG-bodb02
	
	Revisions: 
		- 20251027@Max: Create table [Redmine: #241652]
*/

USE [bodb02]
GO

/****** Object:  Table [dbo].[BetBuilderHybridParlayLog]    Script Date: 10/28/2025 4:29:14 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[BetBuilderHybridParlayLog](
	[LogID] [bigint] IDENTITY(1,1) NOT NULL,
	[LogDate] [datetime] NOT NULL,
	[MatchID] [int] NOT NULL,
	[TransId] [bigint] NOT NULL,
	[Odds] [smallmoney] NOT NULL,
	[Offset] [int] NOT NULL
 CONSTRAINT [PK_BetBuilderHybridParlayLog_ID] PRIMARY KEY NONCLUSTERED 
(
	[LogID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[BetBuilderHybridParlayLog] ADD  CONSTRAINT [DF_BetBuilderHybridParlayLog_LogDate]  DEFAULT (getdate()) FOR [LogDate]
GO

/****** Object:  Index [CIX_BetBuilderHybridParlayLog_LogDate]    Script Date: 10/29/2025 1:14:58 PM ******/
CREATE CLUSTERED INDEX [CIX_BetBuilderHybridParlayLog_LogDate] ON [dbo].[BetBuilderHybridParlayLog]
(
	[LogDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO


/****** Object:  Index [BetBuilderHybridParlayLog]    Script Date: 10/28/2025 4:31:52 PM ******/
CREATE NONCLUSTERED INDEX [IX_BetBuilderHybridParlayLog_MatchID] ON [dbo].[BetBuilderHybridParlayLog]
(
	[MatchID] ASC,
	[TransId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO


