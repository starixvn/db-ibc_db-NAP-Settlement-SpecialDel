/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20220324@Louisa
	Task: Create new table to store ResultDetail/OS/ES update history  [Redmine:#170548]
	DB: DBTP/bodb02
*/

USE bodb02
GO

CREATE TABLE dbo.SettlementResultDetailHistory
(
	TableName			VARCHAR(100),
	MatchId				INT			,
	ResourceId			VARCHAR(20)	,
	OldHomeValue		VARCHAR(50),
	OldAwayValue		VARCHAR(50),
	NewHomeValue		VARCHAR(50),
	NewAwayValue		VARCHAR(50),
	OldModifiedBy		INT,
	NewModfiedBy		INT,
	OldLastModifiedDate	DATETIME,
	NewLastModifiedDate	DATETIME,
	UpdateTime			DATETIME

)
GO

CREATE CLUSTERED INDEX [CIX_SettlementResultDetailHistory_MatchIdUpdateTime] ON [dbo].[SettlementResultDetailHistory]
(
	[UpdateTime]
	,[MatchId]
)
GO

