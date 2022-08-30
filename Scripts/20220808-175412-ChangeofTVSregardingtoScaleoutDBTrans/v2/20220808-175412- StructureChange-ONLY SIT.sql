/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@Max
	Task: Structure change - ONLY FOR SIT [Redmine:#175412]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO

DROP INDEX [IX_TicketVoiding_Void_Service_BroadcastSessionId] ON [TicketVoiding_Void_Service]
GO

ALTER TABLE [TicketVoiding_Void_Service] ALTER COLUMN BroadcastSessionId VARCHAR(50)
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_Void_Service_BroadcastSessionId] ON [dbo].[TicketVoiding_Void_Service]
(
	[BroadcastSessionId]	ASC

)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
