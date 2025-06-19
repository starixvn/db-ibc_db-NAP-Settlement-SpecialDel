    /*<info serverAlias="DBPRO-bodb02,DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20250512@Aries
	Task	  : Enhance the performance for the Multi-sport Page  [Redmine:#223959]
	DB		  : DBPRO/bodb02
	Revisions:
		20250512@Aries: Enhance the performance for the Multi-sport Pager [Redmine:#223959]
*/
USE bodb02
GO


IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SettlementSpecialBettypeProfile_resourceid' AND object_id = OBJECT_ID('SettlementSpecialBettypeProfile'))
BEGIN
    DROP INDEX IX_SettlementSpecialBettypeProfile_resourceid ON SettlementSpecialBettypeProfile 

    CREATE NONCLUSTERED INDEX IX_SettlementSpecialBettypeProfile_ResourceID  ON SettlementSpecialBettypeProfile(ResourceID)
    CREATE NONCLUSTERED INDEX IX_SettlementSpecialBettypeProfile_RefResourceId  ON SettlementSpecialBettypeProfile(RefResourceId)
END
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SettlementSpecialBettypeProfile_SportType' AND object_id = OBJECT_ID('SettlementSpecialBettypeProfile'))
BEGIN
    DROP INDEX IX_SettlementSpecialBettypeProfile_SportType ON SettlementSpecialBettypeProfile
    
    CREATE CLUSTERED INDEX CIX_SettlementSpecialBettypeProfile_SportTypeBetTypeBetID  ON SettlementSpecialBettypeProfile(SportType,BetType,BetID)
END
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_SettlementSpecialBettypeProfile_Bettype_BetID' AND object_id = OBJECT_ID('SettlementSpecialBettypeProfile'))
BEGIN
    DROP INDEX IX_SettlementSpecialBettypeProfile_Bettype_BetID ON SettlementSpecialBettypeProfile 
END
GO
