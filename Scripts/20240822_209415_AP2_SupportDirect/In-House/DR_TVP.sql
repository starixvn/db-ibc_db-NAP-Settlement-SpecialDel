/*<info serverAlias="IRS_DBPRO-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20241010@Aries.Nguyen	
	Task: In-House
	DB: IRS_DBPRO-bodb02
	
	Revisions:
		- 20241010@Aries.Nguyen: Created [RedmineID: #209415]

	Example:			
*/
CREATE TYPE [dbo].[TVP_ReplAutoPayoutSetting] AS TABLE (
	[Id] [INT] NOT NULL
	,[MatchId] [INT] NOT NULL
	,[AutoType] [TINYINT] NOT NULL
	,[Enable] [bit] NULL
	,[WaitingTime] [INT] NULL
	,[Main_HasTrader] [BIT] NULL
	,[Main_NumberProvider] [TINYINT] NULL
	,[Main_PrimaryProvider] [VARCHAR](500) NULL
	,[Main_TotalPrimaryProvider] [TINYINT] NULL
	,[Main_SecondaryProvider] [VARCHAR](500) NULL
	,[Main_TotalSecondaryProvider] [TINYINT] NULL
	,[Main_InactiveProvider] [VARCHAR](500) NULL
	,[EAR_HasTrader] [BIT] NULL
	,[EAR_NumberProvider] [TINYINT] NULL
	,[EAR_PrimaryProvider] [VARCHAR](500) NULL
	,[EAR_TotalPrimaryProvider] [TINYINT] NULL
	,[EAR_SecondaryProvider] [VARCHAR](500) NULL
	,[EAR_TotalSecondaryProvider] [TINYINT] NULL
	,[EAR_WaitingTime] [INT] NULL
	,[EAR_InactiveProvider] [VARCHAR](500) NULL
	,[CreatedDate] [DATETIME] NULL
	,[RepUpdateTime] [DATETIME2](7) NOT NULL
	,[isDeleted] [BIT]
	,[_FetchedTime] [DATETIME2](7)
)
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplAutoPayoutSetting] TO [repl_ap] AS [dbo]
GO
/***************************************************************************/




