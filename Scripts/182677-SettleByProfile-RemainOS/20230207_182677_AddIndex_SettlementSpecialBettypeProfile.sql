/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20230207@Aries
	Task: Apply Settlement by Profile for Remaining Sports [Redmine: #182677]
	DB: DBPRO/bodb02
*/
 
USE bodb02
GO
CREATE NONCLUSTERED INDEX [IX_SettlementSpecialBettypeProfile_Bettype_BetID] ON [dbo].[SettlementSpecialBettypeProfile]
(
	[BetType] ASC,
	[BetID] ASC
) ON [DATA]
GO


CREATE CLUSTERED INDEX [IX_SettlementSpecialBettypeProfile_resourceid] ON [dbo].[SettlementSpecialBettypeProfile]
(
	[ResourceID] ASC
) ON [DATA]
GO


CREATE NONCLUSTERED INDEX [IX_SettlementSpecialBettypeProfile_SportType] ON [dbo].[SettlementSpecialBettypeProfile]
(
	[SportType] ASC
)
INCLUDE([BetType],[BetID])  ON [DATA]
GO

