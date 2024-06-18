/*<info serverAlias="DBCust-CustDB" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Site_SiteDBGroupID_Select]
AS
/*
	Created: 20220830@Tina
	Task : Get scaleout licensee [Redmine: #177220]
	DB: DBCUST/CustDB
	
	Revisions:  
	Param's Explanation:
		- 20220830@Tina: create
		- 20230228@Louisa: Exclude Licensee of Single WL [Redmine:#184093]
		- 20231221@July: Automail - Change sender and recipient for emails sent to Jollysport licensees [Redmine:#198198]
		- 20240614@July: Enhance SP for the service Negative Balance [Redmine:#206523]

*/
BEGIN
	;WITH CTE AS
	(
		SELECT DISTINCT vp.SiteName 
		FROM SiteConfig.dbo.LicVendorProfile vp WITH(NOLOCK)
			INNER JOIN SiteConfig.dbo.configMaster cm WITH(NOLOCK) ON vp.SiteId = cm.SiteId
			INNER JOIN SiteConfig.dbo.configdetail cd WITH(NOLOCK) ON cm.ConfigId = cd.ConfigID
		WHERE cd.KeyName = 'EnableSingleWallet'
			AND cd.KeyValue = 'true'
	)
	SELECT S.[Site], S.SiteDBGroupID, CASE WHEN S.SpecialPlatfrom IN (2,3) THEN 1 ELSE 0 END IsSpecial
	FROM dbo.[Site] S WITH (NOLOCK)
		LEFT JOIN cte vp on s.site = vp.SiteName
	WHERE S.isLicensee = 1
		AND vp.SiteName IS NULL
END
