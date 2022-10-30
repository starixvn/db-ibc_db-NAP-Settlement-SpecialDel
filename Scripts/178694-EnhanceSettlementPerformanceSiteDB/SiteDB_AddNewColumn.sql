/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

ALTER TABLE dbo.SiteDB_SettlementService_CalculationLog ADD SessionId BIGINT CONSTRAINT DF_SiteDB_SettlementService_CalculationLog_SessionId DEFAULT(0) 
GO

ALTER TABLE dbo.SiteDB_SettlementService_CalculationLog ADD IsParallel BIT CONSTRAINT DF_SiteDB_SettlementService_CalculationLog_IsParallel DEFAULT(0) 

