/*<info serverAlias="DBAGE-bodb02, DBBOF-bodb02, DBACC-bodb02,IRS_DBTP-bodb02,DBRepl-ReplDB" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: DBAGE-bodb02, DBBOF-bodb02, DBACC-bodb02,IRS_DBTP-bodb02,DBRepl-ReplDB
	
	Revisions:
		- 20250819@Hughie.Pham: Created [RedmineID: #232955]

	Example:			
*/
CREATE TYPE [dbo].[TVP_ReplResultDetailOutright] AS TABLE (
	[Orid] [INT] NOT NULL
	,[leagueid] [INT] NOT NULL
	,[Teamid] [INT] NOT NULL
	,[Result] [VARCHAR](10) NULL
	,[ResultStatusID] [TINYINT] NULL
	,[SettlementStatusID] [TINYINT] NULL
	,[IsDeadHeat] [BIT] NULL
	,[CreatedBy] [INT] NULL
	,[CreatedDate] [DATETIME] NULL
	,[ModifiedBy] [INT] NULL
	,[ModifiedDate] [DATETIME] NULL
	,[OtherInfo] [VARCHAR](MAX) NULL
	,[RepUpdateTime] [DATETIME2](7) NOT NULL
	,[isDeleted] [BIT]
	,[_FetchedTime] [DATETIME2](7)
)
GO
GRANT EXECUTE ON TYPE::[dbo].[TVP_ReplResultDetailOutright] TO [repl_ap] AS [dbo]
GO
/***************************************************************************/




