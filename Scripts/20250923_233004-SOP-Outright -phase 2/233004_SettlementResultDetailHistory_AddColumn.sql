/*<info serverAlias="DBTP-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

/*
	Created by: 20250930@Hughie
	Task: Apply SOP Outright Phase2  [Redmine:#233004]
	DB: DBTP/bodb02
*/

USE bodb02
GO

CREATE TABLE SettlementResultDetailOutrightHistory (
	TableName				varchar(50)
	,Orid					int
	,leagueid				INT
	,Teamid					INT
	,OldResult				varchar(10)
	,NewResult				varchar(10)
	,OldResultStatusID		tinyint
	,NewResultStatusID		tinyint
	,OldSettlementStatusID	tinyint
	,NewSettlementStatusID	tinyint
	,OldIsdeadHeat			bit
	,NewIsdeadHeat			bit
	,OldSumWon				int
	,NewSumWon				int
	,OldModifiedBy			int
	,NewModfiedBy			int
	,OldModifiedDate		datetime
	,NewModifiedDate		datetime
	,UpdateTime				datetime
	,OldOtherInfo			varchar
	,NewOtherInfo			varchar
	,OldSettledBy			int
	,NewSettledBy			int
)
CREATE CLUSTERED INDEX [CIX_SettlementResultDetailOutrightHistory_MatchIdUpdateTime] ON [dbo].[SettlementResultDetailOutrightHistory]
(
	[UpdateTime] ASC,
	[TableName] ASC,
	[Orid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO