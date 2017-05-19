ALTER PROCEDURE [dbo].[Acc_SiteSel_Licensee]
AS 

/*	Created by: @Sophia
	Date: 20111122
	DB: DBACC/bodb02
	Task:   . List of licensees
			. To separate with the Licensee site, we not to use table bodb_Licensee.dbo.Licensees any more. And now we use the table Site.
			. Accounting > Special Delete > Ticketslisting > Combo Licensees
	Original sp: Acc_LicenseeSelAll
	
	Revisions:	
	 
	Param's Explanation:
*/

SET NOCOUNT ON 
 
SELECT	siteid as LicenseeID, site as LicenseeName
FROM	site WITH(NOLOCK)
WHERE	isLicensee = 1 AND isActive =1 
		AND siteID NOT IN (29,35)
ORDER BY site
 

GO
GRANT EXECUTE ON [dbo].[Acc_SiteSel_Licensee] TO [bodbAdminNet]
GO
GRANT VIEW DEFINITION ON [dbo].[Acc_SiteSel_Licensee] TO [vnteam]
GO
 
 