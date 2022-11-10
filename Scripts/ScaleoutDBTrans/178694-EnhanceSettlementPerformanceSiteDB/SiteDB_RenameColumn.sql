/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE bodb02
GO

EXEC sp_RENAME 'SiteDB_SettlementService_CalculationLog.TransInfoJson' , 'TransInfoJson_delete', 'COLUMN'