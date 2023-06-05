/*<info serverAlias="DBLOG-bodb_CustomerLog,DBLOG-bodb_CustomerLog_archive" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20230414@Aries
	Task: Support OST Team Query Resettlement Log Redmine: #185964
	DB: DBLOG/bodb_CustomerLog,DBLOG/bodb_CustomerLog_archive

*/
USE bodb_CustomerLog
GO

CREATE TABLE dbo.SettlementLog(
	LogID			BIGINT			NOT NULL IDENTITY(1,1),
	LogDate			DATETIME		NOT NULL,
	MatchID			INT				NOT NULL,
	SportType		INT				NULL,
	ActionID		INT				NULL,
	UserID			INT				NULL,
	ResourceID		VARCHAR(20)		NULL,
	HomeValue		VARCHAR(50)		NULL,
	AwayValue		VARCHAR(50)		NULL,
	OtherInfo		VARCHAR(2000)	NULL
) ON [UserLog_Settle]
GO

ALTER TABLE dbo.SettlementLog ADD  CONSTRAINT DF_SettlementLog_LogDate  DEFAULT (GETDATE()) FOR LogDate
GO

CREATE NONCLUSTERED INDEX CIX_SettlementLog_MatchID ON dbo.SettlementLog
(
		Matchid ASC
)  ON [UserLog_Settle]
GO

CREATE CLUSTERED INDEX CIX_SettlementLog_LogDate ON dbo.SettlementLog
(
		LogDate ASC
)  ON [UserLog_Settle]
GO

/*********************************************************************************************************************/

USE bodb_CustomerLog_archive
GO

CREATE TABLE dbo.SettlementLog(
	LogID			BIGINT			NOT NULL,
	LogDate			DATETIME		NOT NULL,
	MatchID			INT				NOT NULL,
	SportType		INT				NULL,
	ActionID		INT				NULL,
	UserID			INT				NULL,
	ResourceID		VARCHAR(20)		NULL,
	HomeValue		VARCHAR(50)		NULL,
	AwayValue		VARCHAR(50)		NULL,
	OtherInfo		VARCHAR(2000)	NULL
) ON [UserLog_Settle]
WITH (DATA_COMPRESSION = PAGE)
GO

CREATE NONCLUSTERED  INDEX CIX_SettlementLog_MatchID ON dbo.SettlementLog
(
		Matchid ASC
)  WITH (DATA_COMPRESSION = PAGE) ON [ps_SETTLE_monthly] (LogDate)
GO

CREATE CLUSTERED INDEX CIX_SettlementLog_LogDate ON dbo.SettlementLog
(
		LogDate ASC
)   WITH (DATA_COMPRESSION = PAGE) ON [ps_SETTLE_monthly] (LogDate)
GO