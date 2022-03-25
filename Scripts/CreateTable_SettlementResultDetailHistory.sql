/*<info serverAlias="DBPRO-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20220324@Louisa
	Task: Create new table to store ResultDetail/OS/ES update history  [Redmine:#]
	DB: DBPRO/bodb02
*/

USE bodb02
GO

CREATE TABLE dbo.SettlementResultDetailHistory
(
	[TableName]		VARCHAR(100)	NOT NULL,
	[MatchId]		INT				NOT NULL,
	[ResourceId]	VARCHAR(20)		NOT NULL,
	[OldHomeValue]	VARCHAR(50),
	[OldAwayValue]	VARCHAR(50),
	[NewHomeValue]	VARCHAR(50),
	[NewAwayValue]	VARCHAR(50),
	[ModifyDate]	DATETIME

)
GO

CREATE NONCLUSTERED INDEX [IX_SettlementResultDetailHistory_MatchIdResourceId] ON [dbo].[SettlementResultDetailHistory]
(
	[MatchId]
	,[ResourceId]
)
GO



