/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Louisa
	Date: 20200731
	Task: Create new tables to store provider info [Redmine:#138656]
	DB: DBPRO/bodb02

	Revisions:
		- 20200731@Louisa: Create new tables to store provider info on DB02
		- 20200803@Louisa: Change column name [Description] to [Remark] on [dbo].[ProviderInfo] and [dbo].ProviderGameTypeMapping][ProviderGameTypeMapping]
						   Rename [dbo].ProviderLeaugeMappingOutsideSource] to [dbo].[ProviderLeagueMappingOutsideSource]
						   CREATE INDEXES
*/

USE [bodb02]
GO

CREATE TABLE [dbo].[ProviderInfo](
	[SourceId]		[smallint]	NOT NULL,
	[SourceName]	[varchar](50)	NOT NULL,
	[Remark]		[nvarchar](1000)	NULL,
	[isActive]		[bit]	NULL
) ON [Event_table]
GO

ALTER TABLE [dbo].[ProviderInfo] ADD CONSTRAINT [DF_ProviderInfo_isActive] DEFAULT(0) FOR [isActive]
GO

CREATE TABLE [dbo].[ProviderGameTypeMapping](
	[PGId]			[int] IDENTITY(1,1) NOT NULL,			
	[SourceId]		[smallint]	NOT NULL,
	[GameType]		[tinyint]	NOT NULL,
	[Remark]		[nvarchar](1000)	NULL,
	[OrderNo]		[int]	NULL,
	[isActive]		[bit]	NULL
) ON [Event_table]
GO

ALTER TABLE [dbo].[ProviderGameTypeMapping] ADD CONSTRAINT [DF_ProviderGameTypeMapping_OrderNo] DEFAULT(0) FOR [OrderNo]
GO

ALTER TABLE [dbo].[ProviderGameTypeMapping] ADD CONSTRAINT [DF_ProviderGameTypeMapping_isActive] DEFAULT(0) FOR [isActive]
GO

CREATE TABLE [dbo].[ProviderLeagueMappingOutsideSource](
	[LeagueId]	[int] NOT NULL,
	[PGId]		[int] NOT NULL,
	[OrderNo]	[int] NULL,
CONSTRAINT [PK_ProviderLeagueMappingOutsideSource] PRIMARY KEY
(
	[LeagueId] ASC,
	[PGId] ASC
)
) ON [Event_table]
GO

ALTER TABLE [dbo].[ProviderLeagueMappingOutsideSource] ADD CONSTRAINT [DF_ProviderLeagueMappingOutsideSource_OrderNo] DEFAULT(0) FOR [OrderNo]
GO

--------------------------------------------------------


CREATE CLUSTERED INDEX CIX_ProviderGameTypeMapping_SourceId ON [dbo].[ProviderGameTypeMapping]
(
	SourceId
)ON [Event_table]
GO


ALTER TABLE [dbo].ProviderGameTypeMapping 
ADD CONSTRAINT PK_ProviderGameTypeMapping 
PRIMARY KEY NONCLUSTERED 
(
	PGId ASC
) ON [Event_table]
GO

ALTER TABLE [dbo].ProviderInfo 
ADD CONSTRAINT PK_ProviderInfo 
PRIMARY KEY CLUSTERED 
(
	SourceId ASC
) ON [Event_table]
GO

