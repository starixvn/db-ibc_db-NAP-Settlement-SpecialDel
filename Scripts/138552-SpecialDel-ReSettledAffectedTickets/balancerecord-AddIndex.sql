/*<info serverAlias="DBBAH-balancerecord" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20200922@Kathy
	Task: Add new index [Redmine:#138552] 
	DB: DBBAH/balancerecord
	
*/
USE BalanceRecord
GO
CREATE NONCLUSTERED INDEX [IX_BalanceRecord_bk_MatchId] ON [dbo].[BalanceRecord_bk]
(
	[MatchId] ASC
)