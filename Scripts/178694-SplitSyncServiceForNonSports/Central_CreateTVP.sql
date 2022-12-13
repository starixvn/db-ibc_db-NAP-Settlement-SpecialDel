/*<info serverAlias="DBCTG-bodb02"></info>*/
USE [bodb02]
GO

CREATE TYPE [dbo].[TVP_SiteDB_CalculationLog_3rd] AS TABLE(
	[LogId] [bigint] NOT NULL,
	[TransInfoJson] [varbinary](max) NULL,
	[TableName] [varchar](128) NULL,
	[MatchId] [int] NULL,
	[Action] [varchar](1) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL
)
GO


GRANT EXEC ON TYPE::[dbo].[TVP_SiteDB_CalculationLog_3rd] TO [bodbadminnet] 
