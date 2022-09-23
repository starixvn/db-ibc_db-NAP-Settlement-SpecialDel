/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@July
	Task: Add new column  [Redmine:#175412]  
	DB: DBCTG.bodb02, DBSIG.bodb02
		   
*/
USE bodb02
GO

ALTER TABLE dbo.TicketVoiding_AutoVoidRequest_Queue ADD BroadcastSessionId VARCHAR(50)
GO

CREATE NONCLUSTERED INDEX [IX_BroadcastSessionId] ON [dbo].[TicketVoiding_AutoVoidRequest_Queue]
(
	[BroadcastSessionId]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO