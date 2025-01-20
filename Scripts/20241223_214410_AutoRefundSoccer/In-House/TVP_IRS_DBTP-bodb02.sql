/*<info serverAlias="IRS_DBTP-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250120@Aries	
	Task: In-House
	DB: IRS_DBTP-bodb02
	
	Revisions:
		- 20250120@Aries: Created [RedmineID: #214410]

	Example:			
*/
CREATE TYPE [dbo].[TVP_ReplAutoRefundSetting] AS TABLE (
	[Id] [INT] NOT NULL
	,[Sporttype] [SMALLINT] NOT NULL
	,[ResourceID] [VARCHAR](20) NOT NULL
	,[Trigger] [VARCHAR](MAX) NULL
	,[Conditions] [VARCHAR](MAX) NULL
	,[CreatedDate] DATETIME NULL
	,[RepUpdateTime] [DATETIME2](7) NOT NULL
	,[isDeleted] [BIT]
	,[_FetchedTime] [DATETIME2](7)
)
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplAutoRefundSetting] TO [repl_ap] AS [dbo]
GO
/***************************************************************************/




