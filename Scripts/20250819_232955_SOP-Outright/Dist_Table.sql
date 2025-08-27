/*<info serverAlias="IRS_DBTP-bodb02, DBRepl-ReplDB, DBAGE-bodb02, DBBOF-bodb02, DBACC-bodb02" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250819@Hughie.Pham	
	Task: In-House
	DB: 
	
	Revisions:
		- 20250819@Hughie.Pham: Created [RedmineID: #232955]

	Example:			
*/
IF NOT EXISTS (SELECT * FROM sys.OBJECTS WHERE NAME = 'ResultDetailOutright')
BEGIN
	CREATE TABLE [dbo].[ResultDetailOutright]
	(
		[Orid] [INT] NOT NULL
		,[leagueid] [INT] NOT NULL
		,[Teamid] [INT] NOT NULL
		,[Result] [VARCHAR](10) NULL
		,[ResultStatusID] [TINYINT] NULL
		,[SettlementStatusID] [TINYINT] NULL
		,[IsDeadHeat] [BIT] NULL
		,[SumWon] [INT] NULL
		,[CreatedBy] [INT] NULL
		,[CreatedDate] [DATETIME] NULL
		,[ModifiedBy] [INT] NULL
		,[ModifiedDate] [DATETIME] NULL
		,[OtherInfo] [VARCHAR](MAX) NULL
		,[RepUpdateTime] [DATETIME2](7) NULL
		,[isDeleted] [BIT] NULL
		,CONSTRAINT [PK_ResultDetailOutright] PRIMARY KEY CLUSTERED ([Orid]) ON [DATA]
	) ON [DATA]

	ALTER TABLE [dbo].[ResultDetailOutright] ADD CONSTRAINT [DF_ResultDetailOutright_isDeleted]  DEFAULT ((0)) FOR [isDeleted]
	
	ALTER TABLE [dbo].[ResultDetailOutright] ADD CONSTRAINT [DF_ResultDetailOutright_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]
	
	CREATE NONCLUSTERED INDEX [IX_ResultDetailOutright_RepUpdateTime] ON [dbo].[ResultDetailOutright] 
	(
	  [RepUpdateTime] ASC
	)ON [DATA]
END
ELSE 
BEGIN
	SELECT 'Table ResultDetailOutright exists!!!'
END
GO
/***************************************************************************/




