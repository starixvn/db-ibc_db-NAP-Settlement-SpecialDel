/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20231205@Louisa
	Task:  Result Amendment Redmine:#196401
	DB: DBTXN-bodb02

	Create table
	   +SettlementResultHistory
	   +SettlementResultHistory_TicketDetails
	Add new column(SessionId)
	   +BalanceNegative
	   +BalanceNegativeHistory

*/

USE bodb02
GO

CREATE TABLE dbo.SettlementResultHistory
(
	 SessionID      VARCHAR(50)		NOT NULL
	,MatchID        INT				NOT NULL
	,SeqNo			SMALLINT		NOT NULL
	,ActualResult   VARCHAR(MAX)
	,WrongResult    VARCHAR(MAX)
	,ActionType		TINYINT			NOT NULL
	,ResultType     TINYINT			NOT NULL
	,Sporttype      SMALLINT		NOT NULL
	,CreatedDate    DATETIME		DEFAULT GETDATE()
	,ModifiedDate   DATETIME		DEFAULT GETDATE()
	,StatusID       TINYINT			
	,ExtraInfo      VARCHAR(MAX)
	,RepUpdateTime  DATETIME2(7)	DEFAULT SYSDATETIME()
	,IsDeleted		BIT				DEFAULT 0
) ON DATA
GO

ALTER TABLE dbo.SettlementResultHistory
ADD CONSTRAINT PK_SettlementResultHistory 
PRIMARY KEY CLUSTERED 
(
	MatchID,SessionID,SeqNo ASC
) ON DATA
GO

CREATE INDEX IDX_SettlementResultHistory_CreatedDate ON dbo.SettlementResultHistory(CreatedDate)
GO
CREATE INDEX IDX_SettlementResultHistory_StatusID ON dbo.SettlementResultHistory(StatusID)
GO
CREATE INDEX IX_RepUpdateTime ON dbo.SettlementResultHistory(RepUpdateTime)
GO
-------------------------------------------------------------------------

CREATE TABLE dbo.SettlementResultHistory_TicketDetails
(
	 SessionID			VARCHAR(50) NOT NULL
	,SeqNo				SMALLINT	NOT NULL
	,Transid			BIGINT	    NOT NULL
	,ExtraInfo_Before	VARCHAR(MAX)
	,ExtraInfo_After	VARCHAR(MAX)
	,RepUpdateTime		DATETIME2(7)	DEFAULT SYSDATETIME()
	,IsDeleted			BIT				DEFAULT 0
) ON DATA
GO

ALTER TABLE dbo.SettlementResultHistory_TicketDetails
ADD CONSTRAINT PK_SettlementResultHistory_TicketDetails
PRIMARY KEY CLUSTERED 
(
	SessionID,Transid ASC
) ON DATA
GO
CREATE INDEX IX_RepUpdateTime ON dbo.SettlementResultHistory_TicketDetails(RepUpdateTime)
GO
-------------------------------------------------------------------------
IF OBJECT_ID('BalanceNegative') IS NOT NULL
	AND NOT EXISTS(	SELECT TOP 1 1 FROM sys.columns c 
					WHERE c.name = 'SessionId' 
					AND c.object_id = OBJECT_ID('BalanceNegative')
					)
BEGIN
	ALTER TABLE BalanceNegative ADD SessionId VARCHAR(50);
END
GO
-------------------------------------------------------------------------

IF OBJECT_ID('BalanceNegativeHistory') IS NOT NULL
	AND NOT EXISTS(	SELECT TOP 1 1 FROM sys.columns c 
					WHERE c.name = 'SessionId' 
					AND c.object_id = OBJECT_ID('BalanceNegativeHistory')
					)
BEGIN
	ALTER TABLE BalanceNegativeHistory ADD SessionId VARCHAR(50);
END
GO

-------------------------------------------------------------------------
IF OBJECT_ID('SiteDB_SettlementService_CalculationLog') IS NOT NULL
	AND NOT EXISTS(	SELECT TOP 1 1 FROM sys.columns c 
					WHERE c.name = 'BroadcastSessionId' 
					AND c.object_id = OBJECT_ID('SiteDB_SettlementService_CalculationLog')
					)
BEGIN
	ALTER TABLE SiteDB_SettlementService_CalculationLog ADD BroadcastSessionId VARCHAR(50) 
END
GO
-------------------------------------------------------------------------

IF OBJECT_ID('SiteDB_SettlementService_CalculationLog') IS NOT NULL
	AND NOT EXISTS (	SELECT TOP 1 1 FROM sys.indexes i 
						WHERE i.name = 'IDX_SiteDB_SettlementService_CalculationLog_BroadcastSessionId'
						AND i.object_id = OBJECT_ID('SiteDB_SettlementService_CalculationLog')
					)
BEGIN
	CREATE INDEX IDX_SiteDB_SettlementService_CalculationLog_BroadcastSessionId ON dbo.SiteDB_SettlementService_CalculationLog(BroadcastSessionId)
END
GO