/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_AutoVoidRequest_Queue_bk](
	[QueueId] [int] NOT NULL,
	[RequestId] [int] NOT NULL,
	[MatchId] [int] NOT NULL,
	[Action] [varchar](100) NULL,
	[StatusId] [tinyint] NULL,
	[UserId] [int] NULL,
	[Starttime] [datetime] NULL,
	[Exectime] [datetime] NULL,
	[Duration] [int] NULL,
	[IP] [varchar](50) NULL,
	[ErrMsg] [varchar](300) NULL,
	[sporttype] [smallint] NULL,

) ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_AutoVoidRequest_Queue_bk] ADD  CONSTRAINT [DF_TicketVoiding_AutoVoidRequest_Queue_bk_Starttime]  DEFAULT (getdate()) FOR [Starttime]
GO

ALTER TABLE [dbo].[TicketVoiding_AutoVoidRequest_Queue_bk] ADD  CONSTRAINT [DF_TicketVoiding_AutoVoidRequest_Queue_bk_Duration]  DEFAULT ((0)) FOR [Duration]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_AutoVoidRequest_Queue_bk_MatchId_StatusID] ON [dbo].[TicketVoiding_AutoVoidRequest_Queue_bk]
(
	[MatchId] ASC,
	[StatusId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO


