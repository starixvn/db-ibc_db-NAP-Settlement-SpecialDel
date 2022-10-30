CREATE TYPE [dbo].[TVP_SiteDB_CalculationLog] AS TABLE(
	[LogId] [bigint] NOT NULL,
	[TransInfo] [varchar](max) NULL,
	[TransInfoJson] [varchar](max) NULL,
	[TableName] [varchar](128) NULL,
	[MatchId] [int] NULL,
	[Action] [varchar](1) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL,
	[SessionId] [bigint] NULL,
	[IsParalell] [bit] NULL
)
GO