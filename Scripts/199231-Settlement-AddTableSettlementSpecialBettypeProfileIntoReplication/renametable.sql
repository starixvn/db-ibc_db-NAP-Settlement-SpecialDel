/*<info serverAlias="DBTXN-bodb02, DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE bodb02
GO

-- DROP all INDEXES
DROP INDEX IX_SettlementSpecialBettypeProfile_Bettype_BetID ON SettlementSpecialBettypeProfile
GO

DROP INDEX IX_SettlementSpecialBettypeProfile_resourceid ON SettlementSpecialBettypeProfile
GO

DROP INDEX IX_SettlementSpecialBettypeProfile_SportType ON SettlementSpecialBettypeProfile
GO

EXEC sp_rename 'SettlementSpecialBettypeProfile ', 'SettlementSpecialBettypeProfile_old';

GO
 
