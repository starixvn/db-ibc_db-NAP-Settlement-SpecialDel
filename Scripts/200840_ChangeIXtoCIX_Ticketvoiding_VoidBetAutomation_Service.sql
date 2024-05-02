/*<info serverAlias="DBCTG-bodb02,DBACC-bodb02" executers="" isFunction="0"></info>*/
/*
    Created: 20240503@July
	Task: Change IX_Ticketvoiding_VoidBetAutomation_Service_RequestID_VoidingHistoryId -> Clustered - [Redmine: #200840]
	DB: DBCTG-bodb02,DBACC-bodb02 [Replicated Server for DBTrans_Sync_DB06]
*/

USE bodb02
GO

--Step 3.Drop old column After Void Service
DROP INDEX [IX_Ticketvoiding_VoidBetAutomation_Service_RequestID_VoidingHistoryId] ON [Ticketvoiding_VoidBetAutomation_Service]
GO

CREATE CLUSTERED INDEX [CIX_Ticketvoiding_VoidBetAutomation_Service_RequestID_VoidingHistoryId] ON [dbo].[Ticketvoiding_VoidBetAutomation_Service]
(
	[RequestID] ASC,
	[VoidingHistoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO
