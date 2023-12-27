/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[SpecialDelete_MailingList_Select]
	@CategoryId		TINYINT = 10
AS

/*
	Created by: 20180919@Alan
	Task : Get Mailing List From OIC
	DB: DBOIC.bodb_OIC

	Revisions:   
		- 20180919@Alan: Get Mailing List From OIC [88509]
		- 20181009@Alan: Exclude Status Soft Launch and Dont add CcList from EmailConfiguration [102917]
		- 20220221@July: Remove SABA of league name for China View sites [168651]
		- 20230830@July: Remove SABA of league name for Jolly View sites [193213]
		- 20231227@July: [TVS] Change email sender of TVS when sending email to Jollysports Licensee [198522]

	Explanation's Param:
		- @CategoryId:
			+ 10: Bet Deletion Report
			+ 7: Abnormal Bet
*/

BEGIN 
	SET NOCOUNT ON 
	
	SELECT
		L.LicenseeId AS siteid
	   ,L.RegisteredLicenseeName AS site
	   ,STUFF(ToList.ContactEmail, 1, 1, '') AS ToList
	   ,STUFF(CcList.ContactEmail, 1, 1, '') AS CcList
	   ,CASE
			WHEN STUFF(ToList.ContactEmail, 1, 1, '') <> '' OR
				STUFF(CcList.ContactEmail, 1, 1, '') <> '' THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
		END isavailabe
	  ,s.IsChinaView
	  ,s.SpecialPlatform --2: JollyView
	FROM dbo.Licensee L WITH (NOLOCK)
		INNER JOIN LicenseeCategoryAssigned LCA WITH (NOLOCK) ON L.LicenseeId = LCA.LicenseeId
		OUTER APPLY (
			SELECT ';' + c.ContactEmail
			FROM dbo.CategoryContact cc WITH (NOLOCK)
				INNER JOIN dbo.Contact c WITH (NOLOCK) ON c.ContactID = cc.ContactID
			WHERE cc.RecipientType = 0
				AND cc.CategoryID = LCA.CategoryId
				AND c.LicenseeID = l.LicenseeId
			ORDER BY c.ContactEmail
			FOR XML PATH ('')) AS ToList (ContactEmail)

		OUTER APPLY (
			SELECT ';' + T.ContactEmail
			FROM (
				SELECT c.ContactEmail
				FROM dbo.CategoryContact cc WITH (NOLOCK)
					INNER JOIN dbo.Contact c WITH (NOLOCK) ON c.ContactID = cc.ContactID
				WHERE cc.RecipientType = 1
					AND cc.CategoryID = LCA.CategoryId
					AND c.LicenseeID = l.LicenseeId

				UNION
				SELECT ult.Email
				FROM dbo.UserLicensee ul WITH (NOLOCK)
					INNER JOIN dbo.UserInfo ui WITH (NOLOCK) ON ul.UserId = ui.UserId
					INNER JOIN dbo.UserLicenseeTypes ult WITH (NOLOCK) ON ui.UserId = ult.UserId AND L.TypeId = ult.TypeId
				WHERE ui.PositionId = 6
					AND L.LicenseeId = ul.LicenseeId

				UNION
				SELECT ult.Email
				FROM dbo.UserInfo ui WITH (NOLOCK)
					INNER JOIN dbo.UserLicenseeTypes ult WITH (NOLOCK) ON ui.UserId = ult.UserId
				WHERE ui.PositionId = 3 AND L.TypeId = ult.TypeId
			) AS T
			ORDER BY T.ContactEmail
			FOR XML PATH ('')) AS CcList (ContactEmail)
		OUTER APPLY	(
					SELECT ISNULL(s.IsChinaView,0) AS IsChinaView
						  ,ISNULL(s.SpecialPlatfrom,0) AS SpecialPlatform
					FROM bodb02.dbo.site s WITH(NOLOCK) 
					WHERE l.RegisteredLicenseeName = s.site 
					)s
	WHERE L.LicenseeStatusId = 3
	AND L.RegisteredLicenseeName IS NOT NULL
	AND LCA.CategoryId = @CategoryId
	ORDER BY site ASC	

	SET NOCOUNT OFF
END
GO