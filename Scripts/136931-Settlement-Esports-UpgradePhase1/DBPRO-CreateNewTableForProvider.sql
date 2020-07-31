/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Luoisa
	Date: 20200731
	Task: Create new table to store provider info [Redmine:#136931]
	DB: DBPRO/bodb02
*/

USE [bodb02]
GO

CREATE TABLE [dbo].[ProviderInfo](
	[SourceId]		[smallint]	NOT NULL,
	[SourceName]	[varchar](50)	NOT NULL,
	[Description]	[nvarchar](1000)	NULL,
	[isActive]		[bit]	NULL
) ON [Event_table]
GO

ALTER TABLE [dbo].[ProviderInfo] ADD CONSTRAINT [DF_ProviderInfo_isActive] DEFAULT(0) FOR [isActive]
GO

CREATE TABLE [dbo].[ProviderGameTypeMapping](
	[PGId]			[int] IDENTITY(1,1) NOT NULL,			
	[SourceId]		[smallint]	NOT NULL,
	[GameType]		[tinyint]	NOT NULL,
	[Description]	[nvarchar](1000)	NULL,
	[OrderNo]		[int]	NULL,
	[isActive]		[bit]	NULL,
CONSTRAINT [PK_ProviderGameTypeMapping] PRIMARY KEY
(
	[PGId] ASC
)
) ON [Event_table]
GO

ALTER TABLE [dbo].[ProviderGameTypeMapping] ADD CONSTRAINT [DF_ProviderGameTypeMapping_OrderNo] DEFAULT(0) FOR [OrderNo]
GO

ALTER TABLE [dbo].[ProviderGameTypeMapping] ADD CONSTRAINT [DF_ProviderGameTypeMapping_isActive] DEFAULT(0) FOR [isActive]
GO

CREATE TABLE [dbo].[ProviderLeaugeMappingOutsideSource](
	[LeagueId]	[int] NOT NULL,
	[PGId]		[int] NOT NULL,
	[OrderNo]	[int] NULL,
CONSTRAINT [PK_ProviderLeaugeMappingOutsideSource] PRIMARY KEY
(
	[LeagueId] ASC,
	[PGId] ASC
)
) ON [Event_table]
GO
ALTER TABLE [dbo].[ProviderLeaugeMappingOutsideSource] ADD CONSTRAINT [DF_ProviderLeaugeMappingOutsideSource_OrderNo] DEFAULT(0) FOR [OrderNo]
GO



