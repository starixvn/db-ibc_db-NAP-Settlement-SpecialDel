/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@Max
	Task: Rename column on Ticketvoiding_VoidBetAutomation_Service [Redmine:#175412]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO

DROP INDEX [IX_Ticketvoiding_VoidBetAutomation_Service_RequestID_VoidingHistory] ON [Ticketvoiding_VoidBetAutomation_Service]
GO

ALTER TABLE [Ticketvoiding_VoidBetAutomation_Service] DROP COLUMN VoidingHistory
GO

CREATE NONCLUSTERED INDEX [IX_Ticketvoiding_VoidBetAutomation_Service_RequestID_VoidingHistoryId] ON [dbo].[Ticketvoiding_VoidBetAutomation_Service]
(
	[RequestID] ASC,
	[VoidingHistoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO