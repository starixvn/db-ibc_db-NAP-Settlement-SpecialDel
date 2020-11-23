/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20201120@Max
	Task: [TVS] HotFix Error Time Out when search request on range _bk with wide range time - [Redmine: #145756]
	DB: DBARC/bodb_Archive
*/

USE bodb_Archive
GO
------[TicketVoiding_RequestDetail_bk]------------
CREATE CLUSTERED INDEX [CIX_TicketVoiding_RequestDetail_bk_RequestId] ON [dbo].[TicketVoiding_RequestDetail_bk]
(
	[RequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_RequestDetail_bk_MatchId] ON [dbo].[TicketVoiding_RequestDetail_bk]
(
	[MatchId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

----------[TicketVoiding_Request_bk]----------------
CREATE NONCLUSTERED INDEX [IX_TicketVoiding_Request_bk_CreatedDate] ON [dbo].[TicketVoiding_Request_bk]
(
	[CreatedDate] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

--------[TicketVoiding_OperatorInfo_bk]----------------
CREATE CLUSTERED INDEX [CIX_TicketVoiding_OperatorInfo_bk_RequestId] ON [dbo].[TicketVoiding_OperatorInfo_bk]
(
	[RequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

--------[TicketVoiding_Queue_bk]-----------
CREATE CLUSTERED INDEX [CIX_TicketVoiding_Queue_bk_VoidingHistoryId] ON [dbo].[TicketVoiding_Queue_bk]
(
	[VoidingHistoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_TicketVoiding_Queue_bk_QueueId] ON [dbo].[TicketVoiding_Queue_bk]
(
	[QueueId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

---------[zzzbettrans_bk]-----------
CREATE NONCLUSTERED INDEX [IX_zzzbettrans_bk_VoidingHistoryId] ON [dbo].[zzzbettrans_bk]
(
	[VoidingHistoryId] ASC
)
WHERE ([VoidingHistoryId] IS NOT NULL)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO



