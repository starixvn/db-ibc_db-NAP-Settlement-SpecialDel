/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230626@Louisa: Prepare data - custid [Redmineid:#181595] 

*/

USE SiteDBtmp
GO

 	DECLARE @MaxCustBeforeUM INT
			,@MaxRecommendBeforeUM 	 INT

	SELECT @MaxCustBeforeUM			= MAX(CustID) FROM CustSiteDB3_20230626  WITH (NOLOCK)
	SELECT @MaxRecommendBeforeUM 	= MAX(CustID) FROM RecommendSiteDB3_20230626  WITH (NOLOCK)

	INSERT INTO CustSiteDB3_20230626 (custid)
	SELECT DISTINCT custid
	FROM CustDB.dbo.Customer c WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
	WHERE s.SiteLabel  = 'IBC' 
		AND c.custid >  @MaxCustBeforeUM

	SELECT @@ROWCOUNT as cnt_newCust

	
	INSERT INTO RecommendSiteDB3_20230626 (custid)
	SELECT DISTINCT custid
	FROM CustDB.dbo.Customer c WITH (NOLOCK)
		INNER JOIN CustDB.dbo.Site s WITH(NOLOCK) ON c.Site = s.Site
	WHERE s.SiteLabel  = 'IBC' 
		AND c.roleid = 2
		AND custid > @MaxRecommendBeforeUM 
	
	SELECT @@ROWCOUNT as cnt_newRecommend

	SELECT COUNT(1) as cnt_Cust FROM CustSiteDB3_20230626
	SELECT COUNT(1) as cnt_Recommend FROM RecommendSiteDB3_20230626
