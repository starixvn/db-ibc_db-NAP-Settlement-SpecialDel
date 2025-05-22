/*<info serverAlias="IRS_DBTP-bodb02,DBCustRepl-ReplCustDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250521@Louisa	
	Task: In-House
	DB: 
	
	Revisions:
		- 20250521@Louisa: Created [RedmineID: #226060]

	Example:			
*/
 
IF NOT EXISTS (SELECT * FROM sys.OBJECTS WHERE NAME = 'CustWinLimitBet')
BEGIN
	CREATE TABLE [dbo].[CustWinLimitBet]
	(
		[CustID] [INT] NOT NULL
		,[Sporttype] [SMALLINT] NOT NULL
		,[Bettype] [INT] NOT NULL
		,[AccumToWin] [MONEY] NULL
		,[AccumWinLoss] [MONEY] NULL
		,[CreatedDate] [DATETIME] NULL
		,[RepUpdateTime] [DATETIME2](7) NULL
		,[isDeleted] [BIT] NULL
		,CONSTRAINT [PK_CustWinLimitBet] PRIMARY KEY CLUSTERED ([CustID],[Sporttype],[Bettype])  
	)  
END
ELSE 
BEGIN
	SELECT 'Table CustWinLimitBet exists!!!'
END
GO
-------------------------------------------------------

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints 
    WHERE name = 'DF_CustWinLimitBet_isDeleted'
)
BEGIN
	ALTER TABLE [dbo].[CustWinLimitBet] ADD CONSTRAINT [DF_CustWinLimitBet_isDeleted]  DEFAULT ((0)) FOR [isDeleted]
END
GO
--------------------------------------------------------

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints 
    WHERE name = 'DF_CustWinLimitBet_RepUpdateTime'
)
BEGIN
	ALTER TABLE [dbo].[CustWinLimitBet] ADD CONSTRAINT [DF_CustWinLimitBet_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]
END
GO
--------------------------------------------------------

IF NOT EXISTS (
    SELECT *
    FROM sys.indexes
    WHERE name = 'IDX_CustWinLimitBet_RepUpdateTime' AND object_id = OBJECT_ID('CustWinLimitBet')
)
BEGIN
	CREATE NONCLUSTERED INDEX [IDX_CustWinLimitBet_RepUpdateTime] ON [dbo].[CustWinLimitBet] 
		(
		  [RepUpdateTime] ASC
		) 
END
GO

/***************************************************************************/
IF NOT EXISTS (SELECT * FROM sys.OBJECTS WHERE NAME = 'CustWinLimitBet_History')
BEGIN
	CREATE TABLE [dbo].[CustWinLimitBet_History]
	(
		[ID] [BIGINT] IDENTITY NOT NULL
		,[CustID] [INT] NOT NULL
		,[Sporttype] [SMALLINT] NULL
		,[Bettype] [INT] NULL
		,[Transid] [BIGINT] NULL
		,[AdjToWin] [MONEY] NULL
		,[AdjWinLoss] [MONEY] NULL
		,[ActionType] [TINYINT] NOT NULL
		,[RepUpdateTime] [DATETIME2](7) NULL
		,[isDeleted] [BIT] NULL
		,CONSTRAINT [PK_CustWinLimitBet_History] PRIMARY KEY CLUSTERED ([ID]) 
	)  
END
ELSE 
BEGIN
	SELECT 'Table CustWinLimitBet_History exists!!!'
END
GO
-------------------------------------------------

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints 
    WHERE name = 'DF_CustWinLimitBet_History_isDeleted'
)
BEGIN
	ALTER TABLE [dbo].[CustWinLimitBet_History] ADD CONSTRAINT [DF_CustWinLimitBet_History_isDeleted]  DEFAULT ((0)) FOR [isDeleted]
END
GO
-----------------------------------------

IF NOT EXISTS (
    SELECT 1
    FROM sys.default_constraints 
    WHERE name = 'DF_CustWinLimitBet_History_RepUpdateTime'
)
BEGIN
	ALTER TABLE [dbo].[CustWinLimitBet_History] ADD CONSTRAINT [DF_CustWinLimitBet_History_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]
END
GO
-----------------------------------------

IF NOT EXISTS (
    SELECT *
    FROM sys.indexes
    WHERE name = 'IDX_CustWinLimitBet_History_RepUpdateTime' AND object_id = OBJECT_ID('CustWinLimitBet_History')
)

	CREATE NONCLUSTERED INDEX [IDX_CustWinLimitBet_History_RepUpdateTime] ON [dbo].[CustWinLimitBet_History] 
	(
	  [RepUpdateTime] ASC
	) 

GO
/***************************************************************************/




