/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250324@Aries
	Task: Enhance data history when updating events and results  [Redmine:#221187]
	DB: DBTP/bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[Match3rd_Tracking](
	[RowId] [bigint] IDENTITY(1,1) NOT NULL,
	[Match3rdId] [int]  NULL,
	[League3rdId] [int]  NULL,
	[HomeId] [int]  NULL,
	[AwayId] [int]  NULL,
	[EventDate] [date]  NULL,
	[SportType] [smallint]  NULL,
	[VendorMatchId] [varchar](50) NULL,
	[MatchNo] [varchar](30) NULL,
	[EventStatus] [varchar](50) NULL,
	[CreateTime] [datetime] NOT NULL,
	[UpdateTime] [datetime] NULL,
	[StartTime] [datetime] NULL,
	[MarketEndTime] [datetime] NULL,
	[BetStatus] [varchar](50) NULL,
	[EndTime] [datetime] NULL,
	[livehomescore] [int] NULL,
	[liveawayscore] [int] NULL,
	[hthomescore] [int] NULL,
	[htawayscore] [int] NULL,
	[finalhomescore] [int] NULL,
	[finalawayscore] [int] NULL,
	[matchcode] [nvarchar](50) NULL,
	[UpdateTimeHistory]	[DATETIME]
    CONSTRAINT [PK_Match3rd_Tracking_RowId] PRIMARY KEY NONCLUSTERED 
    (
	    [RowId] ASC
    )
) 
GO
CREATE CLUSTERED INDEX [CIX_Match3rd_Tracking_Match3rdId] ON [dbo].[Match3rd_Tracking]
(
	[Match3rdId]
)

CREATE NONCLUSTERED INDEX [IX_Match3rd_Tracking_UpdateTimeHistory] ON [dbo].[Match3rd_Tracking]
(
	[UpdateTimeHistory]
)



GO
CREATE TABLE [dbo].[VSOutright_Tracking](
	[RowId] [bigint] IDENTITY(1,1) NOT NULL,
	[Orid] [int]  NULL,
	[EventID] [int] NOT NULL,
	[RacerNum] [tinyint] NULL,
	[IsFavor] [varchar](3) NULL,
	[EventDate] [smalldatetime]  NULL,
	[KickoffTime] [datetime]  NULL,
	[RacerID] [int] NULL,
	[HumanID] [int] NULL,
	[WinOdds] [smallmoney] NULL,
	[PlaceOdds] [smallmoney] NULL,
	[Lane] [tinyint] NULL,
	[MaxBet] [int] NULL,
	[DisplayMode] [tinyint] NULL,
	[Placing] [tinyint] NULL,
	[Colours] [varchar](50) NULL,
	[Creator] [int]  NULL,
	[ChangeTime] [datetime] NULL,
	[EventStatus] [varchar](50) NULL,
	[UpdateTime]	[DATETIME]
    CONSTRAINT [PK_VSOutright_Tracking_RowId] PRIMARY KEY NONCLUSTERED 
    (
	    [RowId] ASC
    )
) 
GO
CREATE CLUSTERED INDEX [CIX_VSOutright_Tracking_Match3rdId] ON [dbo].[VSOutright_Tracking]
(
	[EventID]
)

CREATE NONCLUSTERED INDEX [IX_VSOutright_Tracking_UpdateTime] ON [dbo].[VSOutright_Tracking]
(
	[UpdateTime]
)

GO
CREATE TABLE [dbo].[VSRaceInfo_Tracking](
	[RowId] [bigint] IDENTITY(1,1) NOT NULL,
	[EventTime] [datetime]  NULL,
	[LeagueID] [int]  NULL,
	[PayOut] [tinyint] NULL,
	[EachWay] [tinyint] NULL,
	[CourseName] [varchar](100) NULL,
	[TrackType] [varchar](10) NULL,
	[Distance] [varchar](10) NULL,
	[Racers] [tinyint] NULL,
	[ForeCastPayout] [money] NULL,
	[TriCastPayout] [money] NULL,
	[CreateDate] [smalldatetime]  NULL,
	[Calculate] [bit]  NULL,
	[SportType] [tinyint]  NULL,
	[ChangeTime] [datetime] NULL,
	[BetStatus] [varchar](10) NULL,
	[EventStatus] [nvarchar](50) NULL,
	[VendorMatchId] [varchar](50) NULL,
	[EventID] [int]  NULL,
	[UpdateTime]	[DATETIME],
    CONSTRAINT [PK_VSRaceInfo_Tracking_RowId] PRIMARY KEY NONCLUSTERED 
    (
	    [RowId] ASC
    )
) 
GO
CREATE CLUSTERED INDEX [CIX_VSRaceInfo_Tracking_Match3rdId] ON [dbo].[VSRaceInfo_Tracking]
(
	[EventID]
)

CREATE NONCLUSTERED INDEX [IX_VSRaceInfo_Tracking_UpdateTime] ON [dbo].[VSRaceInfo_Tracking]
(
	[UpdateTime]
)


CREATE NONCLUSTERED INDEX [IX_SMP_MarketSelection_History_UpdateTime] ON [dbo].[SMP_MarketSelection_History]
(
	[LogDate]
)


CREATE NONCLUSTERED INDEX [IX_SMP_Market_History_UpdateTime] ON [dbo].[SMP_Market_History]
(
	[LogDate]
)