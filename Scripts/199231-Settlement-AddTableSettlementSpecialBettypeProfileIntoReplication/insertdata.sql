/*<info serverAlias="DBTXN-bodb02, DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE [bodb02]
GO
INSERT INTO dbo.SettlementSpecialBettypeProfile (pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, OrdNo, RoundID, OddsType
	,RefResourceId, SDTpfId, Is3x30, SDTResourceId, IsSDT, DeterminedType, SpecialType, SDTRefund, SDTInstant)
SELECT pfID, BetType, SportType, BetID, ResourceID, SettleType, GroupType, OrdNo, RoundID, OddsType
	,RefResourceId, SDTpfId, Is3x30, SDTResourceId, IsSDT, DeterminedType, SpecialType, SDTRefund, SDTInstant
FROM dbo.SettlementSpecialBettypeProfile_old