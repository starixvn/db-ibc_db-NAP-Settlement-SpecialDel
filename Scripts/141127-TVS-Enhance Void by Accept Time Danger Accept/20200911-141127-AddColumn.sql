/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20200911@Max
	Task: [TVS] Enhance Void by Accept Time in Void Single Bet and TVS Danger Accept - [Redmine: #141127]
	DB: bodb02 - DBTRANS & Replicated Server for DBTrans_API_Data
*/

USE bodb02
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail]
ADD
    FilterBy		TINYINT	NULL
GO


