/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
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

ALTER TABLE [dbo].[TicketVoiding_OperatorInfo_bk] ADD  CONSTRAINT [PK_TicketVoiding_OperatorInfo_bk_Id] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO


