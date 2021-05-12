/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/  
/*
	Created: 20210512@Kathy
	DB: DBBAH.bodb02
	Task: Insert data to new table if ticket is re-settled [Redmine:#154732]
	
*/
USE [bodb02]
GO
CREATE TABLE [dbo].[SettlementHistory](
	[TransId] [bigint] NULL,
	[MatchId] [int] NULL,
	[SettlementType] [tinyint] NULL,
	[Winlost] [money] NULL,
	[StatusId] [tinyint] NULL,
	[CreatedDate] [datetime] NULL
) ON [Others_table]
GO

ALTER TABLE [dbo].[SettlementHistory] ADD  CONSTRAINT [DF_SettlementHistory_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO


CREATE CLUSTERED INDEX [CIX_SettlementHistory_MatchId] ON [dbo].[SettlementHistory]
(
	[MatchId] ASC
) ON [Others_index]
GO