/*<info serverAlias="DBWH-bodb_dwrs" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250722@Max
	Task	  : Integration - Settlement Time Dashboard report [Redmine:#232227]
	DB		  : DBWH-bodb_dwrs
	Revisions:
		- 20250722@Max: Create structure [Redmine:#232227]
*/
USE bodb_dwrs
GO

CREATE TABLE dbo.SettlementPerformanceReport (
    RowID BIGINT NOT NULL IDENTITY(1,1),
    SportType SMALLINT NOT NULL,
    SportName NVARCHAR(50) NOT NULL,
    LeagueID INT NOT NULL,
    LeagueName NVARCHAR(2000) NOT NULL,
    EventDate DATETIME NOT NULL,
    WaitforKeyscore INT NULL,
    WaitingTimeInQueue INT NULL,
    SiteDBSettleDuration INT NULL,
    SubDBSettleDuration INT NULL,
    TotalDuration INT NULL,
    CreatedDate DATETIME NOT NULL DEFAULT GETDATE()
CONSTRAINT [PK_SettlementPerformanceReport] PRIMARY KEY NONCLUSTERED 
(
	[RowID] ASC
) ON [PRIMARY]
) ON [PRIMARY]

CREATE CLUSTERED INDEX IX_SettlementPerformanceReport_EventDate_SportType_LeagueID
ON SettlementPerformanceReport (EventDate, SportType, LeagueID);

GO


