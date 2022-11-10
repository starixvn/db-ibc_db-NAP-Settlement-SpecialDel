/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE TYPE [dbo].[TVP_SiteDB_CalculationLog] AS TABLE(
	[LogId] [bigint] NOT NULL,
	[TransInfo] xml NULL,
	[TransInfoJson] [varbinary](max) NULL,
	[TableName] [varchar](128) NULL,
	[MatchId] [int] NULL,
	[Action] [varchar](1) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL,
	[SessionId] [bigint] NULL,
	[IsParallel] [bit] NULL
)
GO

GRANT EXEC ON TYPE::[dbo].[TVP_SiteDB_CalculationLog] TO [bodbadminnet] 


