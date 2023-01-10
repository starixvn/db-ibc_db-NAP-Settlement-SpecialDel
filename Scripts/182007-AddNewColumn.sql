/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/
USE bodb_CustomerLog_Archive
GO
ALTER TABLE dbo.SettlementPerformanceLog ADD ResourceId VARCHAR(20)
GO
ALTER TABLE dbo.SettlementPerformanceLog ADD ActionId SMALLINT