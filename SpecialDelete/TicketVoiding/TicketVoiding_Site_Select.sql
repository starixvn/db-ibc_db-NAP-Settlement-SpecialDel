/*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_Site_Select]
AS
/*
	Created by: July
	Task : [TVS] Implement AB Whitelist
	DB: DBACC/bodb02

	Revisions:
		- 20211001@July: Create new SP - Get all site [Redmine:#161659]
*/
BEGIN
	SET NOCOUNT ON

	SELECT
		siteid AS SiteId
	   ,[site] AS SiteName
	   ,CASE WHEN isDeposit = 1 THEN 'Deposit' ELSE 'Credit' END AS GroupName
	FROM dbo.Site WITH(NOLOCK)
	WHERE isActive = 1  
	ORDER BY [site] ASC

	SET NOCOUNT OFF
END
GO
