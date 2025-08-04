/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250804@Hughie
	Task: SOP Outright  [Redmine:#221187]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[ResultDetailOutright](
	[orid] [int] IDENTITY(1,1) NOT FOR REPLICATION NOT NULL
	,[ResultStatusID] [INT] NULL
	,[KeyResultUserId] [INT] NULL
	,[ConfirmUserId] [INT] NULL
	
	,[RowId] [bigint] IDENTITY(1,1) NOT NULL
	,[Match3rdId] [int]  NULL
	,[League3rdId] [int]  NULL
	,[HomeId] [int]  NULL
	,[AwayId] [int]  NULL
	,[EventDate] [date]  NULL
	,[SportType] [smallint]  NULL
	,[VendorMatchId] [varchar](50) NULL
	,[MatchNo] [varchar](30) NULL
	,[EventStatus] [varchar](50) NULL
	,[CreateTime] [datetime] NOT NULL
	,[UpdateTime] [datetime] NULL
	,[StartTime] [datetime] NULL
	,[MarketEndTime] [datetime] NULL
	,[BetStatus] [varchar](50) NULL
	,[EndTime] [datetime] NULL
	,[livehomescore] [int] NULL
	,[liveawayscore] [int] NULL
	,[hthomescore] [int] NULL
	,[htawayscore] [int] NULL
	,[finalhomescore] [int] NULL
	,[finalawayscore] [int] NULL
	,[matchcode] [nvarchar](50) NULL
	,[UpdateTimeHistory]	[DATETIME]
    CONSTRAINT [PK_ResultDetailOutright_orid] PRIMARY KEY NONCLUSTERED 
    (
	    [orid] ASC
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
