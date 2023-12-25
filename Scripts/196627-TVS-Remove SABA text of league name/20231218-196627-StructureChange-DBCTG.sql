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
