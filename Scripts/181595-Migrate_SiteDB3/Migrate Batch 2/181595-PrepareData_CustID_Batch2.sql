/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230816@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230816@Louisa: Migrate Credit Batch 2 - Nova88, 789y, Inactive sites, except 222227 and CN88  [Redmineid:#181595] 

*/ 

USE SiteDBtmp
GO

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
		INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) 
			ON c.Site = s.Site
	WHERE ISNULL(s.SiteLabel, '')  <> 'IBC' 
		AND s.isLicensee = 0 
		AND s.Site NOT IN (  '222227', 'CN88')

	GO
 
SELECT COUNT(1) as cnt_CustID FROM CustSiteDB3_20230626
