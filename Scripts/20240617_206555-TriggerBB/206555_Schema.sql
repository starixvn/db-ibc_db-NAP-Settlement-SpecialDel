/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created by: 20240617@Aries
	Task: Trigger to capture data for Betbuider  [Redmine:#206555]
	DB: DBTP/bodb02
*/
USE  bodb02

CREATE TABLE [dbo].[SMP_Market_History](
	[RowId]	[BIGINT] IDENTITY(1,1),
	[MatchId] [int],
	[MarketId] [varchar](20),
	[VendorId] [smallint],
	[OldPrice] [smallmoney],
	[NewPrice] [smallmoney],
	[OldTradeStatus] [varchar](20),
	[NewTradeStatus] [varchar](20),
	[OldResult] [varchar](20),
	[NewResult] [varchar](20),
	[OldResultStatusId] [tinyint],
	[NewResultStatusId] [tinyint],
	[OldSelectionCounts] [tinyint],
	[NewSelectionCounts] [tinyint],
	[OldCreateTime] [datetime],
	[NewCreateTime] [datetime],
	[OldUpdateTime] [datetime],
	[NewUpdateTime] [datetime],
	[LogDate] [datetime],
	 CONSTRAINT [PK_SMP_Market_History] PRIMARY KEY NONCLUSTERED 
	(
		[RowId] 
	)
)

CREATE CLUSTERED INDEX [CIX_SMP_Market_History] ON [dbo].[SMP_Market_History]
(
	 [MatchId]
	,[MarketId]
)
GO


CREATE TABLE [dbo].[SMP_MarketSelection_History](
	[RowId]	[BIGINT] IDENTITY(1,1),
	[MarketSelectionId] [bigint],
	[MatchId] [int],
	[MarketId] [varchar](20),
	[SelectionType] [int],
	[OldResult] [varchar](20),
	[NewResult] [varchar](20),
	[OldResultStatusId] [tinyint],
	[NewResultStatusId] [tinyint],
	[LogDate] [datetime],
	 CONSTRAINT [PK_SMP_MarketSelection_History] PRIMARY KEY NONCLUSTERED 
	(
		[RowId] 
	)
)

CREATE CLUSTERED INDEX [CIX_SMP_MarketSelection_History] ON [dbo].[SMP_MarketSelection_History]
(
	 [MatchId]
	,[MarketId]
)
GO
