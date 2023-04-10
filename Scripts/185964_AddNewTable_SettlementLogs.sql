/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created: 20230410@Louisa
	Task: write log for interval result [Redmine:#185964]
	DB: DBLOG/bodb_CustomerLog

	Revisions: 
		- 20230410@Louisa [Redmine:#185964]


*/

USE bodb_CustomerLog
GO

CREATE TABLE SettlementLogs
(
	Sporttype		SMALLINT	NOT NULL
	,MatchID		INT			NOT NULL
	,LeagueGroupId	INT
	,ActionID		INT			NOT NULL
	,ResourceID		VARCHAR(50)
	,HomeValue		VARCHAR(50)
	,AwayValue		VARCHAR(50)
	,UserID			INT
	,LogDate		DATETIME2	NOT NULL
	,LogType		TINYINT --2: completed action, 3: fail
)
ON [DATA]

GO

ALTER TABLE SettlementLogs ADD CONSTRAINT DF_SettlementLogs_LogDate DEFAULT GETDATE() FOR LogDate
GO

CREATE CLUSTERED INDEX CIX_SettlementLogs_MatchID_LogDate ON SettlementLogs ( MatchID, LogDate)
GO

CREATE NONCLUSTERED INDEX IX_SettlementLogs_MatchID_LogDate ON SettlementLogs ( Sporttype, LogDate, ActionID)
GO

----drop table SettlementLogs

