/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/

USE [bodb02]
GO
/*  Creator: 20210514@Kathy
	Task: New table to lock parlay refno
	DB: DBTXN/BODB02

*/
CREATE TABLE [dbo].[ParlayLocking](
	[MatchId] [int] NULL,
	[Refno] [bigint] NULL,
	[Session] [nvarchar](50) NULL,
	[SPName] [sysname] NULL,
	[CreatedDate] [datetime] NULL
) ON [DATA]
GO

ALTER TABLE [dbo].[ParlayLocking] ADD  CONSTRAINT [DF_ParlayLocking_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO

CREATE UNIQUE CLUSTERED INDEX [CIX_ParlayLocking_Refno] ON [dbo].[ParlayLocking]
(
	[Refno] ASC
) ON [DATA]

GO
CREATE NONCLUSTERED INDEX [IX_ParlayLocking_MatchId] ON [dbo].[ParlayLocking]
(
	[MatchId] ASC
)ON [DATA]
GO


CREATE TABLE [dbo].[ParlayLockingHistory](
	[MatchId] [int] NULL,
	[Refno] [bigint] NULL,
	[Session] [nvarchar](50) NULL,
	[SPName] [sysname] NULL,
	[CreatedDate] [datetime] NULL,
	Action VARCHAR(1)
) ON [DATA]
GO

ALTER TABLE [dbo].[ParlayLockingHistory] ADD  CONSTRAINT [DF_ParlayLockingHistory_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO
CREATE CLUSTERED INDEX [CIX_ParlayLockingHistory_MatchId_Refno] ON [dbo].[ParlayLockingHistory]
(
	[MatchId] ASC,
	[Refno] ASC
) ON [DATA]
GO
