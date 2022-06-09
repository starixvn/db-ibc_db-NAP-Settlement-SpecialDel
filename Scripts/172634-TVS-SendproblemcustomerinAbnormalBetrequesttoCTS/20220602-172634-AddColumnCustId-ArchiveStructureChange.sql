/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220602@July
	Task: [TVS] Send problem customer in Abnormal Bet request to CTS - [Redmine: #172634]
	DB: DBARC/bodb_Archive
*/

USE bodb_Archive
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetailTicket_Single_bk] ADD CustId INT NULL
GO

