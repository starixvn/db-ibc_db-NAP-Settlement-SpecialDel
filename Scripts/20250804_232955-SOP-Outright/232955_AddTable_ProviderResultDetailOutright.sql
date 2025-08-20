/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250804@Hughie
	Task: SOP Outright  [Redmine:#232955]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TABLE [dbo].[ProviderResultDetailOutright](
	 [ProviderId] [INT] NOT NULL IDENTITY(1,1) 
	,[Orid] [int] NOT NULL
	,[SourceId] [SMALLINT] NOT NULL
	,[Leagueid] [int] NOT NULL
	,[Teamid] [int] NOT NULL
	,[Result] [varchar](10) NULL
	,[ResultStatusID] [tinyint] NULL
	,[CreatedBy] [int] NULL
	,[CreatedDate] [datetime] NULL
	,[RepUpdateTime] [datetime2](7) NULL
	,[OtherInfo] [varchar](max) NULL
	,CONSTRAINT [PK_ProviderResultDetailOutright] PRIMARY KEY CLUSTERED ([ProviderId]) ON [DATA]
	) ON [DATA]
	
	ALTER TABLE [dbo].[ProviderResultDetailOutright] ADD CONSTRAINT [DF_ProviderResultDetailOutright_RepUpdateTime]  DEFAULT (SYSDATETIME()) FOR [RepUpdateTime]

	CREATE NONCLUSTERED INDEX [IX_ProviderResultDetailOutright_RepUpdateTime] ON [dbo].[ProviderResultDetailOutright] 
	(
	  [RepUpdateTime] ASC
	) ON [DATA]
GO