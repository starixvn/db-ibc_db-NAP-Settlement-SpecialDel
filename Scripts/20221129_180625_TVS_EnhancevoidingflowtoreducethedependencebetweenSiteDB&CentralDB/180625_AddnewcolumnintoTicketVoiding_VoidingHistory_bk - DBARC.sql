/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Add column MinWinlostDate,MaxWinlostDate, BroadcastSessionID,SiteDBGroupID into TicketVoiding_VoidingHistory_bk [Redmine:#180625]  
	DB: DBARC.bodb_Archive
	
*/
USE bodb_Archive
GO
ALTER TABLE dbo.TicketVoiding_VoidingHistory_bk
ADD
	MinWinlostDate	DATETIME NULL,
	MaxWinlostDate	DATETIME NULL,
	BroadcastSessionID VARCHAR(100),
	SiteDBGroupID SMALLINT
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_VoidingHistory_bk_BroadcastSessionID] ON [dbo].[TicketVoiding_VoidingHistory_bk]
(
	[BroadcastSessionID]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

