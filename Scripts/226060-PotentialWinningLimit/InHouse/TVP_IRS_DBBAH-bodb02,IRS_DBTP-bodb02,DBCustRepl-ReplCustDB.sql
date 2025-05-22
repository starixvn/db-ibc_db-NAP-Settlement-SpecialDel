/*<info serverAlias="IRS_DBBAH-bodb02,IRS_DBTP-bodb02,DBCustRepl-ReplCustDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250521@Louisa	
	Task: In-House
	DB: IRS_DBBAH-bodb02,IRS_DBTP-bodb02,DBCustRepl-ReplCustDB
	
	Revisions:
		- 20250521@Louisa: Created [RedmineID: #226060]

	Example:			
*/
CREATE TYPE [dbo].[TVP_ReplCustWinLimitBet] AS TABLE (
	[CustID] [INT] NOT NULL
	,[Sporttype] [SMALLINT] NOT NULL
	,[Bettype] [INT] NOT NULL
	,[AccumToWin] [MONEY] NULL
	,[AccumWinLoss] [MONEY] NULL
	,[CreatedDate] [DATETIME] NULL
	,[RepUpdateTime] [DATETIME2](7) NOT NULL
	,[isDeleted] [BIT]
	,[_FetchedTime] [DATETIME2](7)
)
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplCustWinLimitBet] TO [repl_ap] AS [dbo]
GO
/***************************************************************************/
CREATE TYPE [dbo].[TVP_ReplCustWinLimitBet_History] AS TABLE (
	[ID] [BIGINT] NOT NULL
	,[CustID] [INT] NOT NULL
	,[Sporttype] [SMALLINT] NULL
	,[Bettype] [INT] NULL
	,[Transid] [BIGINT] NULL
	,[AdjToWin] [MONEY] NULL
	,[AdjWinLoss] [MONEY] NULL
	,[ActionType] [TINYINT] NOT NULL
	,[RepUpdateTime] [DATETIME2](7) NOT NULL
	,[isDeleted] [BIT]
	,[_FetchedTime] [DATETIME2](7)
)
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplCustWinLimitBet_History] TO [repl_ap] AS [dbo]
GO
/***************************************************************************/




