/*<info serverAlias="DBCust-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
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

*/
BEGIN
	SELECT S.[Site], S.SiteDBGroupID
	FROM dbo.[Site] S WITH (NOLOCK)
		OUTER APPLY (
						SELECT TOP(1) vp.SiteID
						FROM SiteConfig.dbo.LicVendorProfile vp WITH(NOLOCK)
							INNER JOIN SiteConfig.dbo.configMaster cm WITH(NOLOCK)
								ON vp.SiteId = cm.SiteId
							INNER JOIN SiteConfig.dbo.configdetail cd WITH(NOLOCK)
								ON cm.ConfigId = cd.ConfigID
						WHERE cd.KeyName = 'EnableSingleWallet'
							AND cd.KeyValue = 'true'
							AND vp.SiteName = s.site
					) vp
	WHERE S.isLicensee = 1
		AND vp.SiteID IS NULL
END
