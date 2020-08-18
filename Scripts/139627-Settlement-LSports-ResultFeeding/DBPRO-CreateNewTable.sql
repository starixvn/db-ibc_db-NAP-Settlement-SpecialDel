/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Louisa
	Date: 20200818
	Task: Create new tables for L-Sports [Redmine:#139627]
	DB: DBPRO/bodb02

	Revisions:
		- 20200818@Louisa: Create new tables for L-Sports [Redmine:#139627]
*/

USE [bodb02]
GO

CREATE TABLE [dbo].[ProviderExternalResultDetailOS]
(
	[ProviderExternalId] [int] IDENTITY(1,1) NOT NULL,
	[MatchId3rd]	[int] NOT NULL,
	[MatchId]		[int] NOT NULL,
	[SourceId]		[smallint] NOT NULL,
	[ResourceId]	[varchar](20) NOT NULL,
	[HomeValue]		[varchar](50) NULL,
	[AwayValue]		[varchar](50) NULL,
	[OtherInfo]		[varchar](50) NULL,
	[CreateDate]	[datetime] NULL,
	[LastModifyDate] [datetime] NULL,
	[CreateBy]		[int] NULL,
	[LastModifyBy] [int] NULL,
	CONSTRAINT [PK_ProviderExternalResultDetailOS] PRIMARY KEY NONCLUSTERED 
	(
		[ProviderExternalId] ASC
	)
) ON [Event_table]
GO

ALTER TABLE [dbo].[ProviderExternalResultDetailOS] ADD  CONSTRAINT [DF_ProviderExternalResultDetailOS_MatchId]  DEFAULT (0) FOR [MatchId]
GO
ALTER TABLE [dbo].[ProviderExternalResultDetailOS] ADD  CONSTRAINT [DF_ProviderExternalResultDetailOS_CreateDate]  DEFAULT (getdate()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[ProviderExternalResultDetailOS] ADD  CONSTRAINT [DF_ProviderExternalResultDetailOS_LastModifyDate]  DEFAULT (getdate()) FOR [LastModifyDate]
GO

CREATE TABLE [dbo].[ProviderExternalResultDetailOS14]
(
	[ProviderExternalId] [int] NOT NULL,
	[MatchId3rd]	[int] NOT NULL,
	[MatchId]		[int] NOT NULL,
	[SourceId]		[smallint] NOT NULL,
	[ResourceId]	[varchar](20) NOT NULL,
	[HomeValue]		[varchar](50) NULL,
	[AwayValue]		[varchar](50) NULL,
	[OtherInfo]		[varchar](50) NULL,
	[CreateDate]	[datetime] NULL,
	[LastModifyDate] [datetime] NULL,
	[CreateBy]		[int] NULL,
	[LastModifyBy] [int] NULL,
	CONSTRAINT [PK_ProviderExternalResultDetailOS14] PRIMARY KEY NONCLUSTERED 
	(
		[ProviderExternalId] ASC
	)
) ON [Event14_table]
GO

--------------------CREATE INDEXES-------------------------------------------

CREATE CLUSTERED INDEX [CIX_ProviderExternalResultDetailOS_MatchId] ON [dbo].[ProviderExternalResultDetailOS]
(
	[MatchId] ASC
) ON [Event_table]
GO

CREATE NONCLUSTERED INDEX [IX_ProviderExternalResultDetailOS_MatchId3rd] ON [dbo].[ProviderExternalResultDetailOS]
(
	[MatchId3rd] ASC
)ON [Event_table]
GO

