/*
    Created: 20200701@Max
	Task: [TVS] Danger Accept Bets Issue Type - [Redmine: #111573]
	DB: bodb02 - DBTRANS & Replicated Server for DBTrans_Bet
*/

USE bodb02
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail]
ADD
    FilterFromTransTime		DATETIME	NULL,
	FilterToTransTime		DATETIME	NULL,
	FilterFromBetId			BIGINT		NULL,
	FilterToBetId			BIGINT		NULL,
	IsFilterByTransTime		BIT			NULL,
	SingleCount				INT			NULL,
	MainParlayCount			INT			NULL,
	MinSingleTransId		BIGINT		NULL,
	MaxSingleTransId		BIGINT		NULL,
	MinMainParlayTransId	BIGINT		NULL,
	MaxMainParlayTransId	BIGINT		NULL,
	VoidFromTime			DATETIME	NULL,
	VoidToTime				DATETIME	NULL
GO

CREATE TABLE [dbo].[TicketVoiding_RequestDetailTicket_Single](
	[Id]				INT	IDENTITY (1,1),
	[RequestId]			INT		NOT NULL,
	[IssueTypeId]		INT		NOT NULL,
	[SubIssueTypeId]	INT		NOT NULL,
	[TransId]			BIGINT	NOT NULL,
	[MatchId]			INT		NOT NULL
 CONSTRAINT [PK_TicketVoiding_RequestDetailTicket_Single] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
	
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [DATA]
) ON DATA
CREATE CLUSTERED INDEX [CIX_TicketVoiding_RequestDetailTicket_Single_Request] ON [dbo].[TicketVoiding_RequestDetailTicket_Single]
(
	RequestId ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
CREATE NONCLUSTERED INDEX [IX_TicketVoiding_RequestDetailTicket_Single_MatchId_TransId] ON [dbo].[TicketVoiding_RequestDetailTicket_Single]
(
	MatchId,
	TransId
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

CREATE TABLE [dbo].[TicketVoiding_RequestDetailTicket_SubParlay](
	[Id]				INT	IDENTITY (1,1),
	[RequestId]			INT		NOT NULL,
	[IssueTypeId]		INT		NOT NULL,
	[SubIssueTypeId]	INT		NOT NULL,
	[TransId]			BIGINT	NOT NULL,
	[MatchId]			INT		NOT NULL
  CONSTRAINT [PK_TicketVoiding_RequestDetailTicket_SubParlay] PRIMARY KEY NONCLUSTERED 
(
	[Id] ASC
	
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [DATA]
) ON DATA
CREATE CLUSTERED INDEX [CIX_TicketVoiding_RequestDetailTicket_SubParlay_Request] ON [dbo].[TicketVoiding_RequestDetailTicket_SubParlay]
(
	RequestId ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO
CREATE NONCLUSTERED INDEX [IX_TicketVoiding_RequestDetailTicket_SubParlay_MatchId_TransId] ON [dbo].[TicketVoiding_RequestDetailTicket_SubParlay]
(
	MatchId,
	TransId
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [DATA]
GO

