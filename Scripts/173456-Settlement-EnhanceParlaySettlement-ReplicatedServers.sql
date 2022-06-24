/*<info serverAlias="DB05-bodb02, DB05BK1-bodb02, DB052-bodb02, DB053-bodb02, DB061-bodb02, DB062-bodb02, DBTP10C-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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
DROP INDEX [IX_matchid] ON [dbo].[BetParlayDetail]
GO
ALTER TABLE [dbo].[BetParlayDetail] DROP COLUMN [rID]
GO
