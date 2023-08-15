/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Prepare data - custid [Redmineid:#181595] 

*/

USE SiteDBtmp
GO

----- 1. all cust IBC

IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects where name = 'CustSiteDB3_20230626')
BEGIN
	CREATE TABLE CustSiteDB3_20230626
	(
		custid INT PRIMARY KEY
	)
END
GO

TRUNCATE TABLE CustSiteDB3_20230626
GO

INSERT INTO CustSiteDB3_20230626 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer c WITH (NOLOCK)
	INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
WHERE s.SiteLabel  = 'IBC' 

GO

SELECT COUNT(1) as cnt_CustID FROM CustSiteDB3_20230626


----- 2. all  recommend 
IF NOT EXISTS (SELECT TOP 1 1 FROM sys.objects where name = 'RecommendSiteDB3_20230626')
BEGIN
	CREATE TABLE RecommendSiteDB3_20230626
	(
		custid INT PRIMARY KEY
	)
END
GO

TRUNCATE TABLE RecommendSiteDB3_20230626
GO

INSERT INTO RecommendSiteDB3_20230626 (custid)
SELECT DISTINCT custid
FROM CustDB.dbo.Customer c WITH (NOLOCK)
	INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
WHERE s.SiteLabel  = 'IBC' 
	AND c.roleid = 2

GO

SELECT COUNT(1) as cnt_Recommend FROM RecommendSiteDB3_20230626


