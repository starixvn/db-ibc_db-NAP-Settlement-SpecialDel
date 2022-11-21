/*<info serverAlias="DBSIG-SiteDB02tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221107@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBSIG-SiteDB02tmp

	 Revisions:
		- 20221107@Victoria: SELECT data INTO new tables for [Redmineid:#180033] 
								1. CustDB.dbo.Customer
*/

USE SiteDB02tmp
GO

CREATE TABLE cust_migration
(
	custid INT PRIMARY KEY
)

------------------------------------------------
INSERT INTO cust_migration (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN	('Betway')
