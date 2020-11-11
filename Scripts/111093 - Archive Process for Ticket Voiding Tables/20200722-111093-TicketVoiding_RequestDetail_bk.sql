/*<info serverAlias="DBARC-bodb_Archive" executers="" selecters="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20200722@Max
	Task: [TVS] Archive process for Ticket Voiding tables - [Redmine: #111093]
	DB: DBARC/bodb_Archive
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[TicketVoiding_RequestDetail_bk](
	[Id] [int] NOT NULL,
	[RequestId] [int] NOT NULL,
	[MatchId] [int] NOT NULL,
	[LeagueId] [int] NULL,
	[HomeId] [int] NULL,
	[AwayId] [int] NULL,
	[KickOffTime] [datetime] NULL,
	[LiveHomeScore] [int] NULL,
	[LiveAwayScore] [int] NULL,
	[IssueDetail] [nvarchar](300) NULL,
	[TransIds] [varchar](max) NULL,
	[RequestType] [tinyint] NULL,
	[FilterFromTransTime] [datetime] NULL,
	[FilterToTransTime] [datetime] NULL,
	[FilterFromBetId] [bigint] NULL,
	[FilterToBetId] [bigint] NULL,
	[IsFilterByTransTime] [bit] NULL,
	[SingleCount] [int] NULL,
	[MainParlayCount] [int] NULL,
	[MinSingleTransId] [bigint] NULL,
	[MaxSingleTransId] [bigint] NULL,
	[MinMainParlayTransId] [bigint] NULL,
	[MaxMainParlayTransId] [bigint] NULL,
	[VoidFromTime] [datetime] NULL,
	[VoidToTime] [datetime] NULL,
	[IsCheckedHomeTeam] [bit] NULL,
	[IsCheckedAwayTeam] [bit] NULL,
	[FilterBy] [tinyint] NULL,

) ON [DATA] TEXTIMAGE_ON [DATA]
GO

ALTER TABLE [dbo].[TicketVoiding_RequestDetail_bk] ADD  CONSTRAINT [DF_TicketVoiding_RequestDetail_bk_RequestType]  DEFAULT ((0)) FOR [RequestType]
GO


