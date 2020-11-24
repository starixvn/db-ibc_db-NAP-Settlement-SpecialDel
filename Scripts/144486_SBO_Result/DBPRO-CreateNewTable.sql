/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20201109@Louisa
	Task: New tables for SBO result [Redmine:#144486]
	DB: DBPRO/bodb02

*/

USE [bodb02]
GO

CREATE TABLE [dbo].[ProviderExternalResultDetail]
(
	[ProviderExternalId] [int] IDENTITY(1,1) NOT NULL,
	[MatchId3rd]		[int] NOT NULL,
	[MatchId]			[int] NOT NULL,
	[SourceId]			[smallint] NOT NULL,
	[ResourceId]		[varchar](20) NOT NULL,
	[HomeValue]			[varchar](50) NULL,
	[AwayValue]			[varchar](50) NULL,
	[OtherInfo]			[varchar](50) NULL,
	[CreateDate]		[datetime] NULL,
	[LastModifyDate]	[datetime] NULL,
	[CreateBy]			[int] NULL,
	[LastModifyBy]		[int] NULL,
	CONSTRAINT [PK_ProviderExternalResultDetail] PRIMARY KEY NONCLUSTERED 
	(
		[ProviderExternalId] ASC
	)
) ON [Event_table]
GO

ALTER TABLE [dbo].[ProviderExternalResultDetail] ADD  CONSTRAINT [DF_ProviderExternalResultDetail_MatchId]  DEFAULT (0) FOR [MatchId]
GO
ALTER TABLE [dbo].[ProviderExternalResultDetail] ADD  CONSTRAINT [DF_ProviderExternalResultDetail_CreateDate]  DEFAULT (GETDATE()) FOR [CreateDate]
GO
ALTER TABLE [dbo].[ProviderExternalResultDetail] ADD  CONSTRAINT [DF_ProviderExternalResultDetail_LastModifyDate]  DEFAULT (GETDATE()) FOR [LastModifyDate]
GO

CREATE TABLE [dbo].[ProviderExternalResultDetail14]
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
	CONSTRAINT [PK_ProviderExternalResultDetail14] PRIMARY KEY NONCLUSTERED 
	(
		[ProviderExternalId] ASC
	)
) ON [Event14_table]
GO

--------------------CREATE INDEXES-------------------------------------------

CREATE CLUSTERED INDEX [CIX_ProviderExternalResultDetail_MatchId] ON [dbo].[ProviderExternalResultDetail]
(
	[MatchId] ASC
) ON [Event_table]
GO

CREATE NONCLUSTERED INDEX [IX_ProviderExternalResultDetail_MatchId3rd] ON [dbo].[ProviderExternalResultDetail]
(
	[MatchId3rd] ASC
)ON [Event_table]
GO
