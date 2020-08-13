/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_Queue_bk](
	[QueueId] [int] NOT NULL,
	[RequestId] [int] NOT NULL,
	[MatchId] [int] NOT NULL,
	[VoidingHistoryId] [int] NOT NULL,
	[TransIds] [varchar](max) NULL,
	[StatusId] [tinyint] NULL,
	[UserId] [int] NULL,
	[Starttime] [datetime] NULL,
	[Exectime] [datetime] NULL,
	[Duration] [int] NULL,
	[IP] [varchar](50) NULL,
	[VoidingTypeId] [tinyint] NULL,
	[TotalTicket] [int] NULL,
	[ErrMsg] [varchar](300) NULL,
	[FailedTransIds] [varchar](max) NULL,
	[NegativeBalanceUsers] [varchar](max) NULL
) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_Queue_bk] ADD  CONSTRAINT [DF_TicketVoiding_Queue_bk_Starttime]  DEFAULT (getdate()) FOR [Starttime]
GO

ALTER TABLE [dbo].[TicketVoiding_Queue_bk] ADD  CONSTRAINT [DF_TicketVoiding_Queue_bk_Duration]  DEFAULT ((0)) FOR [Duration]
GO


