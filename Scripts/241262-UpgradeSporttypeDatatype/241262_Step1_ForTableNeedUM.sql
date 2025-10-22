/*<info serverAlias="DBPRO-bodb02,DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02,DBKLC1-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Created: 20251020@Max
	Task: Synegy - Integration - Upgrade SprottypeID_ data type
	DB: DBPRO-bodb02,DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02,DBKLC1-bodb02
	Revisions:	
		- 20251020@Max: Script alter column for UM table [Redmine: #241262]
*/

USE bodb02
GO

--drop index
DROP INDEX [CIX_SettlementSpecialBettypeProfile_SportTypeBetTypeBetID] ON [dbo].[SettlementSpecialBettypeProfile] WITH ( ONLINE = OFF )
GO

--alter column
ALTER TABLE SettlementSpecialBettypeProfile ALTER COLUMN SportType SMALLINT NOT NULL
GO

--create index again
CREATE CLUSTERED INDEX [CIX_SettlementSpecialBettypeProfile_SportTypeBetTypeBetID] ON [dbo].[SettlementSpecialBettypeProfile]
(
	[SportType] ASC,
	[BetType] ASC,
	[BetID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [DATA]
GO
