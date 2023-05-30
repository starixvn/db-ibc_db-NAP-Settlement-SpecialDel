/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230522@July
	Task: TVS - Manage request - Add index Single_Calculate_Queue - [Redmine:#188153]  
	DB: DBLOG-bodb_CustomerLog_Archive
*/

USE bodb_CustomerLog_Archive
GO

CREATE NONCLUSTERED INDEX [IX_Single_Calculate_Queue_bk_MatchId] ON [dbo].[Single_Calculate_Queue_bk]
(
	[MatchId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO
