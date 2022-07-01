/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/*
	Created: Kathy
	Date: 20220624
	Task : Drop column + index on table BetParlayDetail/BetParlayResult [Redmine:#173456]
*/

USE [bodb02]
GO

--BetParlayDetail
ALTER TABLE [dbo].[BetParlayDetail] DROP CONSTRAINT [PK_BetParlayDetail]
GO
DROP INDEX [IX_matchid_bettype] ON [dbo].[BetParlayDetail]
GO
ALTER TABLE [dbo].[BetParlayDetail] DROP COLUMN [rID]
GO
