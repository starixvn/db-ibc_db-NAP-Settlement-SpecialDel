/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

CREATE TABLE dbo.Service_Settlement_SiteDB_CalculationLog
(
	LogId BIGINT IDENTITY(1,1) 
	,SystemName VARCHAR(50)
	,FunctionName VARCHAR(50)
	,TableName VARCHAR(128)
	,Action VARCHAR(1)
	,MatchId INT
	,TransInfo XML
	,LogDate DATETIME2
) ON [DATA]
GO
ALTER TABLE dbo.Service_Settlement_SiteDB_CalculationLog ADD  CONSTRAINT [DF_Service_Settlement_SiteDB_CalculationLog_LogDate]  DEFAULT (SYSDATETIME()) FOR [LogDate]
GO
ALTER TABLE dbo.Service_Settlement_SiteDB_CalculationLog ADD  CONSTRAINT [DF_Service_Settlement_SiteDB_CalculationLog_MatchId]  DEFAULT (0) FOR [MatchId]
GO
ALTER TABLE dbo.Service_Settlement_SiteDB_CalculationLog ADD  CONSTRAINT [DF_Service_Settlement_SiteDB_CalculationLog_Action]  DEFAULT ('U') FOR [Action]
GO
CREATE TABLE dbo.Service_Settlement_SiteDB_LastLog
(
	LogId BIGINT
	,StatusId TINYINT
	,LastLogId BIGINT
	,LastStatusId TINYINT
	,IsSkip BIT
)ON [DATA]
GO
ALTER TABLE dbo.Service_Settlement_SiteDB_LastLog ADD  CONSTRAINT [DF_Service_Settlement_SiteDB_LastLog_IsSkip]  DEFAULT (0) FOR [IsSkip]
GO

