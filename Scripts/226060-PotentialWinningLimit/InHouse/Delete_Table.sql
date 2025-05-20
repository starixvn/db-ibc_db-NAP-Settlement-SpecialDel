/*<info serverAlias="DBSIC-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250509@Louisa	
	Task: In-House
	DB: 
	
	Revisions:
		- 20250509@Louisa: Created [RedmineID: #226060]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM sys.OBJECTS WHERE NAME = 'CustWinLimitBet_Del_InHouse')
BEGIN
	CREATE TABLE [dbo].[CustWinLimitBet_Del_InHouse]
	(
		[CustID] [INT] NOT NULL
		,[Sporttype] [SMALLINT] NOT NULL
		,[Bettype] [INT] NOT NULL
		) ON [DATA]

	ALTER TABLE [dbo].[CustWinLimitBet_Del_InHouse] ADD [RepUpdateTime] DATETIME2(7) CONSTRAINT [DF_CustWinLimitBet_Del_InHouse_RepUpdateTime] DEFAULT (SYSDATETIME())

	CREATE CLUSTERED INDEX [CIX_CustWinLimitBet_Del_InHouse_RepUpdateTime] ON [dbo].[CustWinLimitBet_Del_InHouse]([RepUpdateTime] ASC) ON [DATA]
END
ELSE 
BEGIN
	SELECT 'Table CustWinLimitBet_Del_InHouse exists!!!'
END
GO
/***************************************************************************/
IF NOT EXISTS (SELECT * FROM sys.OBJECTS WHERE NAME = 'CustWinLimitBet_History_Del_InHouse')
BEGIN
	CREATE TABLE [dbo].[CustWinLimitBet_History_Del_InHouse]
	(
		[ID] [BIGINT] NOT NULL
		) ON [DATA]

	ALTER TABLE [dbo].[CustWinLimitBet_History_Del_InHouse] ADD [RepUpdateTime] DATETIME2(7) CONSTRAINT [DF_CustWinLimitBet_History_Del_InHouse_RepUpdateTime] DEFAULT (SYSDATETIME())

	CREATE CLUSTERED INDEX [CIX_CustWinLimitBet_History_Del_InHouse_RepUpdateTime] ON [dbo].[CustWinLimitBet_History_Del_InHouse]([RepUpdateTime] ASC) ON [DATA]
END
ELSE 
BEGIN
	SELECT 'Table CustWinLimitBet_History_Del_InHouse exists!!!'
END
GO
/***************************************************************************/




