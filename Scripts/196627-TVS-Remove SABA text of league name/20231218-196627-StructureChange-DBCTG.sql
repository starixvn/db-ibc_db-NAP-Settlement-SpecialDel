/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
	Created: 20231218@Max
	Task: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
	DB: DBCTG/bodb02
		
*/

USE [bodb02]
GO

ALTER TABLE dbo.TicketVoiding_VoidingHistory ADD [MessageIdSpecial] INT
GO

ALTER TABLE dbo.Ticketvoiding_VoidBetAutomation_Service ADD [MessageIdSpecial] INT
GO

ALTER TABLE dbo.[TicketVoiding_VoidedTransaction] ADD
	[winlostdate] [smalldatetime] NULL,
	[status] [nvarchar](10) NULL,
	[bettype] [int] NULL,
	[stake] [money] NULL,
	[winlost] [money] NULL,
	[VoidingHistoryId] [int] NULL,
	[SiteDBGroupID] [smallint] NULL
GO