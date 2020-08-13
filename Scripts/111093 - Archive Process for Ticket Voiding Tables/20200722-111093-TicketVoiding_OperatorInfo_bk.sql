/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_OperatorInfo_bk](
	[RequestId] [int] NOT NULL,
	[OperatorId] [int] NOT NULL,
	[OperatorTypeId] [tinyint] NOT NULL,
	[Id] [int] NOT NULL,

) ON [DATA]
GO


