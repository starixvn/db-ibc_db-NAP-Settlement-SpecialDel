/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20200922@Kathy
	Task: Add new index [Redmine:#138552] 
	DB: DBBAH/BODB02
	
*/

USE bodb02
GO
CREATE NONCLUSTERED INDEX [IX_BalanceRecord_MatchId] ON [dbo].[BalanceRecord]
(
	[MatchId] ASC
) ON [BALANCE]
GO
