/*<info serverAlias="DBARC-bodb_Archive" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Kathy
	Date: 20200716
	Task: Create new table to store provider result [Redmine:#136931]
	DB: DBARC/bodb_Archive
*/
USE bodb_Archive
GO

CREATE TABLE [dbo].[ProviderExternalResultDetailES_bk](
	[ProviderExternalId] [int] NOT NULL,
	[MatchId3rd] [int] NOT NULL,
	[MatchId] [int] NOT NULL,
	[SourceId] [smallint] NOT NULL,
	[ResourceId] [varchar](20) NOT NULL,
	[HomeValue] [varchar](50) NULL,
	[AwayValue] [varchar](50) NULL,
	[OtherInfo] [varchar](50) NULL,
	[CreateDate] [datetime] NULL,
	[CreateBy] [int] NULL,
	[LastModifyDate] [datetime] NULL,
	[LastModifyBy] [int] NULL,
 CONSTRAINT [PK_ProviderExternalResultDetailES14] PRIMARY KEY NONCLUSTERED 
(
	[ProviderExternalId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [EVENT]
) ON [EVENT]
GO
