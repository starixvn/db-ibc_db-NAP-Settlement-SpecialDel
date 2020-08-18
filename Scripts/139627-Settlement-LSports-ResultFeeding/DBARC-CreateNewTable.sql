/*<info serverAlias="DBARC-bodb_Archive" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Louisa
	Task: Create new tables for L-Sports [Redmine:#139627]
	DB: DBARC/bodb_Archive

	Revisions:
		- 20200818@Louisa: Create new tables for L-Sports [Redmine:#139627]
*/

USE [bodb_Archive]
GO

CREATE TABLE [dbo].[ProviderExternalResultDetailOS_bk]
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
	CONSTRAINT [PK_ProviderExternalResultDetailOS_bk] PRIMARY KEY NONCLUSTERED 
	(
		[ProviderExternalId] ASC
	)
) ON [Event]
GO
