/*<info serverAlias="DBSIG-SiteDB01tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20221229@July
    Task: Data Migration - Real Licensee - PRO - SITEDB01
    DB: DBCTG-SiteDB01tmp

	 Revisions:
		- 20221229@July: SELECT data INTO new tables for CustDB.dbo.Customer [Redmineid:#181575] 
*/

USE SiteDB01tmp
GO

CREATE TABLE cust_20221229
(
	custid INT PRIMARY KEY
)

------------------------------------------------
INSERT INTO cust_20221229 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN ('ZFRT152','ZFRT166SW','4300','aws03','MTechCV','Fabbet','GSCFTWCV','Betway')
