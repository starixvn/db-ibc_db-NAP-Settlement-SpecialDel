/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20210819@Louisa
    Task: Create Index on table dbo.SettlementSpecialBettypeProfile  
    DB: DBTXN-bodb02

	 Revisions:
		- 20210819@Louisa: Create Index on column Sporttype [Redmine:#160192]
*/

USE bodb02
GO


CREATE NONCLUSTERED INDEX [IX_SettlementSpecialBettypeProfile_SportType]
ON [dbo].[SettlementSpecialBettypeProfile] ([SportType])
INCLUDE ( [BetType],[BetID] )
WITH ( ONLINE = ON )
ON [DATA]

GO