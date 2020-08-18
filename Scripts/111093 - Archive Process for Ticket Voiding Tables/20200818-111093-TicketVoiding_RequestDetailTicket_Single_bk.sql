/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20200818@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_RequestDetailTicket_Single_bk](
	[Id] [int] NOT NULL,
	[RequestId] [int] NOT NULL,
	[IssueTypeId] [int] NOT NULL,
	[SubIssueTypeId] [int] NOT NULL,
	[TransId] [bigint] NOT NULL,
	[MatchId] [int] NOT NULL,

) ON [DATA]
GO

CREATE CLUSTERED INDEX [CIX_TicketVoiding_RequestDetailTicket_Single_bk_Request] ON [dbo].[TicketVoiding_RequestDetailTicket_Single_bk]
(
	[RequestId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE NONCLUSTERED INDEX [IX_TicketVoiding_RequestDetailTicket_Single_bk_MatchId_TransId] ON [dbo].[TicketVoiding_RequestDetailTicket_Single_bk]
(
	[MatchId] ASC,
	[TransId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

