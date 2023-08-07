/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Prepare cust IBC on SiteDB3 for checking data [Redmineid:#181595] 

*/

---Run on SiteDB3 only

USE bodb02
GO

	IF EXISTS (SELECT TOP 1 1 FROM sys.objects where name = 'Customer_SiteDB_Migrate_xtest')
	BEGIN
		DROP TABLE Customer_SiteDB_Migrate_xtest
	END
	GO

	SELECT DISTINCT custid 
	INTO Customer_SiteDB_Migrate_xtest
	FROM CustDB.dbo.Customer c WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
	WHERE s.SiteLabel  = 'IBC' 

	SELECT COUNT(1) as cnt_CustID FROM Customer_SiteDB_Migrate_xtest