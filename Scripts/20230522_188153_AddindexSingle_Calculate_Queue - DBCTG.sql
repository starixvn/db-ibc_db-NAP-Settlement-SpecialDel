/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230522@July
	Task: TVS - Manage request - Add index Single_Calculate_Queue - [Redmine:#188153]  
	DB: DBCTG-bodb02
*/

USE bodb02
GO

CREATE NONCLUSTERED INDEX [IX_Single_Calculate_Queue_MatchId] ON [dbo].[Single_Calculate_Queue]
(
	[MatchId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [Event_table]
GO

