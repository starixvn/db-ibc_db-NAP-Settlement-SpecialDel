/*<info serverAlias="DBARC-bodb_Archive" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20201109@Louisa
	Task: New tables for SBO result [Redmine:#144486]
	DB: DBARC/bodb_Archive

*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[ProviderExternalResultDetail_bk]
(
	[ProviderExternalId] [int]  NOT NULL,
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
	[LastModifyBy]	[int] NULL,
	CONSTRAINT [PK_ProviderExternalResultDetail_bk] PRIMARY KEY NONCLUSTERED 
	(
		[ProviderExternalId] ASC
	)
) ON [Event]
GO