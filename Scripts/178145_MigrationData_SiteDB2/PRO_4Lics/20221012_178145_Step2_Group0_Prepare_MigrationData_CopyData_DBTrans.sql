/*<info serverAlias="DBSIG-SiteDB02tmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Real Licensee - PRO - SITEDB02
    DB: DBCTG-SiteDB02tmp

	 Revisions:
		- 20220926@Victoria: SELECT data INTO new tables for CustDB.dbo.Customer [Redmineid:#178145] 
*/

USE SiteDB02tmp
GO

CREATE TABLE cust_20221006
(
	custid INT PRIMARY KEY
)

------------------------------------------------
INSERT INTO cust_20221006 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer WITH (NOLOCK)
WHERE site IN	('OneSports', '9club', 'X2Dynamic', 'Macaubet')