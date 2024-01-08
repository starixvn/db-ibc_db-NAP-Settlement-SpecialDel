/*<info serverAlias="DBTXN-bodb02, DB02-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

DROP INDEX IX_SettlementSpecialBettypeProfile_Bettype_BetID ON SettlementSpecialBettypeProfile
GO
DROP INDEX IX_SettlementSpecialBettypeProfile_resourceid ON SettlementSpecialBettypeProfile
GO
DROP INDEX IX_SettlementSpecialBettypeProfile_SportType ON SettlementSpecialBettypeProfile
GO
EXEC sp_rename 'SettlementSpecialBettypeProfile', 'SettlementSpecialBettypeProfile_old'
GO

