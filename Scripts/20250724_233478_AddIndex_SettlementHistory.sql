/*<info serverAlias="DBBAH-bodb02" executers="" isFunction="0"></info>*/
/*
	Created: 20250724@July
	Task: [TVS] Get Result Amendment for main parlay ticket of matchid input [Redmine: #233478]
	DB: DBBAH-bodb02
*/
USE bodb02;
GO

CREATE NONCLUSTERED INDEX [IX_SettlementHistory_TransId] ON [dbo].[SettlementHistory]
(
	[TransId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [Others_index]
GO

