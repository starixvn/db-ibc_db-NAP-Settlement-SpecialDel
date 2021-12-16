/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Max
	Date 20211116
	Task: [TVS] Void abnormal bet of parlay
	DB: DBTXN/bodb02
*/

USE [bodb02]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_AutoVoidRequest_Queue_RequestId] ON [dbo].[TicketVoiding_AutoVoidRequest_Queue]
(
	[RequestId] ASC
) WITH (ONLINE = ON) ON [DATA]
GO
