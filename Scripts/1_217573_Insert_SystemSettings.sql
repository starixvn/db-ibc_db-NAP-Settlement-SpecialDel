/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Created: 20250716@Louisa
	Task:  CO Jacktime [Redmine:#217573] 
	DB: DBSIG/bodb02
	
	Revisions:
		- 20250716@Louisa: CO Jacktime [Redmine:#217573] 

*/

---run all SITEDB

USE bodb02
GO

DECLARE @MaxValue VARCHAR(20) = (SELECT CAST( MAX(l.LogId) AS VARCHAR(20)) FROM dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK))

INSERT INTO dbo.SystemSettings ( VName, VValue )
VALUES ('SiteDB_CO_LastLogId', @MaxValue )
