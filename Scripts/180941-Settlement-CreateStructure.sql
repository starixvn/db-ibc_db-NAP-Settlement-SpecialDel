

USE [bodb_CustomerLog_Archive]
GO

CREATE TABLE [dbo].[Single_Calculate_Queue_bk](
	[matchid] [int] NOT NULL,
	[eventdate] [datetime] NULL,
	[IsCalculating] [int] NULL,
	[AdminId] [int] NULL,
	[IP] [varchar](15) NULL,
	[Starttime] [datetime] NULL,
	[Action] [varchar](20) NULL,
	[sqlCommand] [nvarchar](max) NULL,
	[TryCount] [int] NULL,
	[execTime] [datetime] NULL,
	[duration] [int] NULL
) ON [ps_SETTLE_monthly]([Starttime])
WITH
(
DATA_COMPRESSION = PAGE
)
GO

CREATE CLUSTERED INDEX [CIX_Single_Calculate_Queue_bk_MatchId] ON [dbo].[Single_Calculate_Queue_bk]
(
	[matchid] ASC
)WITH (DATA_COMPRESSION = PAGE) ON [ps_SETTLE_monthly]([Starttime])
GO

CREATE NONCLUSTERED INDEX [IX_Single_Calculate_Queue_bk_Starttime] ON [dbo].[Single_Calculate_Queue_bk]
(
	[Starttime] ASC
)WITH (DATA_COMPRESSION = PAGE) ON [ps_SETTLE_monthly]([Starttime])
GO


--==
CREATE TABLE [dbo].[Parlay_Calculate_Queue_bk](
	[matchid] [int] NOT NULL,
	[eventdate] [datetime] NULL,
	[IsCalculating] [int] NULL,
	[Creator] [int] NULL,
	[IP] [varchar](15) NULL,
	[Starttime] [datetime] NULL,
	[Action] [varchar](20) NULL,
	[TryCount] [int] NULL,
	[execTime] [datetime] NULL,
	[duration] [int] NULL
) ON [ps_SETTLE_monthly]([Starttime])
WITH
(
DATA_COMPRESSION = PAGE
)
GO

CREATE CLUSTERED INDEX [CIX_Parlay_Calculate_Queue_bk_MatchId] ON [dbo].[Parlay_Calculate_Queue_bk]
(
	[matchid] ASC
) WITH (DATA_COMPRESSION = PAGE) ON [ps_SETTLE_monthly]([Starttime])
GO

CREATE NONCLUSTERED INDEX [IX_Parlay_Calculate_Queue_bk_Starttime] ON [dbo].[Parlay_Calculate_Queue_bk]
(
	[Starttime] ASC
)WITH (DATA_COMPRESSION = PAGE) ON [ps_SETTLE_monthly]([Starttime])
GO

--==
CREATE TABLE [dbo].[SettlementPerformanceLog](
	[LeagueId] [int] NULL,
	[MatchId] [int] NULL,
	[HomeId] [int] NULL,
	[AwayId] [int] NULL,
	[Kickofftime] [datetime] NULL,
	[GlobalShowtime] [datetime] NULL,
	[Action] [varchar](20) NULL,
	[IsAuto] [bit] NULL,
	[AdminId] [int] NULL,
	[HomeScore] [int] NULL,
	[AwayScore] [int] NULL,
	[ConfirmScoreDate] [datetime] NULL,
	[Starttime] [datetime] NULL,
	[Exectime] [datetime] NULL,
	[Duration] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[Sporttype] [smallint] NULL,
	[IsHold] [bit] NULL
) ON [ps_SETTLE_monthly]([Starttime])
WITH
(
DATA_COMPRESSION = PAGE
)
GO

CREATE CLUSTERED INDEX [CIX_SettlementPerformanceLog_CreatedDate] ON [dbo].[SettlementPerformanceLog]
(
	[CreatedDate] ASC
)WITH (DATA_COMPRESSION = PAGE) ON [ps_SETTLE_monthly]([Starttime])
GO

