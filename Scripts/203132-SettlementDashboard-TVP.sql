/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

drop proc NAP_SettlementService_CalculationLog_3rdIns
drop proc NAP_SettlementService_PendingLog_3rdIns

DROP TYPE [dbo].[TVP_SiteDB_CalculationLog_3rd]
GO

CREATE TYPE [dbo].[TVP_SiteDB_CalculationLog_3rd] AS TABLE(
	[LogId] [bigint] NOT NULL,
	[TransInfoJson] [varbinary](max) NULL,
	[TableName] [varchar](128) NULL,
	[MatchId] [int] NULL,
	[Action] [varchar](1) NULL,
	[SettlementAction] [varchar](20) NULL,
	[TicketType] [varchar](1) NULL,
	EventTable tinyint null
)
GO


GRANT EXEC ON TYPE::[dbo].[TVP_SiteDB_CalculationLog_3rd] TO [wsv_nap] 
