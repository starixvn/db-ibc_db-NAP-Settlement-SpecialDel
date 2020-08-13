/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_Reason_bk](
	[ReasonId] [int] NOT NULL,
	[ReasonEnglish] [nvarchar](150) NULL,
	[ReasonChineseSimplified] [nvarchar](150) NULL,

) ON [DATA]
GO


