/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230626@Louisa: Pick an inactice site 222227 to paractice  [Redmineid:#181595] 

*/

----- Pickup inactice site 222227 to paractice

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
		INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
	WHERE s.Site= '222227'

	GO


SELECT COUNT(1) as cnt_CustID FROM CustSiteDB3_20230626
