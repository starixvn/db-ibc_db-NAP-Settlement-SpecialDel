/*<info serverAlias="DBPRO-bodb02, DBAGE-bodb02, DBBOF-bodb02, DBACC-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250804@Hughie
	Task: SOP Outright  [Redmine:#232955]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[ResultDetailOutright](
	[Orid] [INT] NOT NULL
	,[leagueid][INT] NOT NULL
	,[Teamid] [INT] NOT NULL
	,[Result][VARCHAR](10)NULL
	,[ResultStatusID] [TINYINT] NULL
	,[SettlementStatusID] [TINYINT] NULL
	,[IsDeadHeat] [BIT] NULL
	,[SumWon] [INT] NULL
	,[CreatedBy] [INT] NULL
	,[CreatedDate] [DATETIME] NULL
	,[ModifiedBy] [INT] NULL
	,[ModifiedDate] [DATETIME] NULL
	,[RepUpdateTime] [DATETIME2] NULL
	,[OtherInfo] [VARCHAR](MAX) NULL
    ,CONSTRAINT [PK_ResultDetailOutright] PRIMARY KEY CLUSTERED ([Orid]) ON [DATA]
	) ON [DATA]
	
	ALTER TABLE [dbo].[ResultDetailOutright] ADD CONSTRAINT [DF_ResultDetailOutright_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]

	CREATE NONCLUSTERED INDEX [IX_ResultDetailOutright_RepUpdateTime] ON [dbo].[ResultDetailOutright] 
	(
	  [RepUpdateTime] ASC
	) ON [DATA]
GO