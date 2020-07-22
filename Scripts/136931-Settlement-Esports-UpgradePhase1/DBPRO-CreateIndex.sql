/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: Kathy
	Date: 20200716
	Task: Create index [Redmine:#136931]
	DB: DBPRO/bodb02
*/

USE [bodb02]
GO
CREATE CLUSTERED INDEX [CIX_ProviderExternalResultDetailES_MatchId] ON [dbo].[ProviderExternalResultDetailES]
(
	[MatchId] ASC
) ON [Event_table]
GO

CREATE NONCLUSTERED INDEX [IX_ProviderExternalResultDetailES_MatchId3rd] ON [dbo].[ProviderExternalResultDetailES]
(
	[MatchId3rd] ASC
)ON [Event_table]
GO
