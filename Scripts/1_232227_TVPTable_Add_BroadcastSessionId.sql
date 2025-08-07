/*<info serverAlias="DBCTG-bodb02"></info>*/
/*
	Created by: 20250709@Louisa
	Task: capture BroadcastSessionId  [Redmine:#232227]

	Revision:
		20250709@Louisa: Settlement Time Dashboard report  [Redmine:#232227]

*/
USE bodb02
GO

CREATE TYPE dbo.TVP_SiteDB_SettlementService AS TABLE
(
	LogId				bigint			NOT NULL 
	,TransInfo			xml				NULL
	,TransInfoJson		varbinary(max)  NULL 
	,TableName			varchar(128)	NULL 
	,MatchId			int				NULL 
	,Action				varchar(1)		NULL 
	,SettlementAction	varchar(20)		NULL 
	,TicketType			varchar(1)		NULL 
	,SessionId			bigint			NULL
	,IsParallel			bit				NULL
	,BroadcastSessionId	varchar(50)		NULL
)
GO

GRANT EXEC ON TYPE::dbo.TVP_SiteDB_SettlementService TO wsv_nap
GO


ALTER TABLE SiteDB_SettlementProcessing ADD BroadcastSessionId	varchar(50) NULL
GO

