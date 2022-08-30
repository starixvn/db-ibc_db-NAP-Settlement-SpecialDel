/*<info serverAlias="DBCust-CustDB" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Acc_Site_SiteDBGroupID_Select]
AS
/*
	Created: 20220830@Tina
	Task : Get scaleout licensee [Redmine: #177220]
	DB: DBCUST/CustDB
	Original:
	Revisions:  
	Param's Explanation:
		- 20220830@Tina: create

*/
BEGIN
	SELECT S.[site], S.SiteDBGroupID
	FROM dbo.[Site] S WITH (NOLOCK)
	WHERE S.isLicensee = 1 AND S.SiteDBGroupID > 0
END
