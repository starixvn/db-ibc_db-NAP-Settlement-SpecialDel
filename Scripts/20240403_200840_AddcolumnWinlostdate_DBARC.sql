/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20240403@July
	Task: [TVS] SP tuning for EC2024 [Redmine: #200840]
	DB: DBARC/bodb_Archive
*/

USE bodb_Archive
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetailTicket_Single_bk] ADD Winlostdate SMALLDATETIME NULL
GO
