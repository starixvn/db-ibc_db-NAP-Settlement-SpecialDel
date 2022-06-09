/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220602@July
	Task: [TVS] Send problem customer in Abnormal Bet request to CTS - [Redmine: #172634]
	DB: DBTXN-bodb02 & Replicated Server for DBTrans_Sync_DB06 & DBTrans_API_Data
*/

USE bodb02
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetailTicket_Single] ADD CustId INT NULL
GO
