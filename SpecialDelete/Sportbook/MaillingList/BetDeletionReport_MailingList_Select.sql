/*<info serverAlias="DBOIC-bodb_OIC" executers="bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[BetDeletionReport_MailingList_Select]
AS

/*
	Created by: 20180919@Alan
	Task : Get Mailing List From OIC
	DB: DBOIC.bodb_OIC

	Revisions:   
		- 20180919@Alan: Get Mailing List From OIC [88509]	
*/

BEGIN 
SET NOCOUNT ON 

	DECLARE @FuncID INT = 287

	SELECT
		L.LicenseeId AS siteid
	   ,L.RegisteredLicenseeName AS site
	   ,STUFF(ToList.ContactEmail, 1, 1, '') AS ToList
	   ,STUFF(CcList.ContactEmail, 1, 1, '') AS CcList
	   ,(SELECT TOP 1 BccList FROM EmailConfiguration(NOLOCK)) AS BccList
	   ,CASE
			WHEN STUFF(ToList.ContactEmail, 1, 1, '') <> '' OR
				STUFF(CcList.ContactEmail, 1, 1, '') <> '' THEN CAST(1 AS BIT)
			ELSE CAST(0 AS BIT)
		END isavailabe

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
					INNER JOIN dbo.UserLicenseeType ult WITH (NOLOCK) ON ui.UserId = ult.UserId AND L.LicenseeTypeId = ult.LicenseeTypeId
				WHERE ui.PositionId = 6
					AND L.LicenseeId = ul.LicenseeId

				UNION
				SELECT ult.Email
				FROM dbo.UserInfo ui WITH (NOLOCK)
					INNER JOIN dbo.UserLicenseeType ult WITH (NOLOCK) ON ui.UserId = ult.UserId
				WHERE ui.PositionId = 3
					AND L.LicenseeTypeId = ult.LicenseeTypeId

				UNION
				SELECT CcList
				FROM dbo.EmailConfiguration WITH (NOLOCK)) AS T
			ORDER BY T.ContactEmail
			FOR XML PATH ('')) AS CcList (ContactEmail)

	WHERE L.LicenseeStatusId = 3
	AND L.RegisteredLicenseeName IS NOT NULL
	AND LCA.CategoryId = 10

	UNION ALL
	SELECT SiteId, '12EU', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000000

	UNION ALL 
	SELECT SiteId, 'IT QA', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000001

	UNION ALL 
	SELECT SiteId, 'IT Support', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000002

	UNION ALL 
	SELECT SiteId, 'Foobet', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000003

	UNION ALL
	SELECT SiteId, 'CSD Recovery', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000004

	UNION ALL
	SELECT SiteId, 'BetFair', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000005

	UNION ALL
	SELECT SiteId, 'OneExchange', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000006
		
	UNION ALL
	SELECT SiteId, 'BetTrade', ToList, CcList, BccList,
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe  
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)
	WHERE FuncID = @FuncID 
	and SiteId = 1000007
		
	UNION ALL  
	SELECT SiteId, 'Cash Out', ToList, CcList, BccList,  
		CASE WHEN tolist IS NOT NULL OR cclist IS NOT NULL OR bcclist IS NOT NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END isavailabe    
	FROM DBACC.BODB_ACC.dbo.Acc_MailingList WITH(NOLOCK)  
	WHERE FuncID = @FuncID   
	and SiteId = 1000008
	ORDER BY site ASC
	
SET NOCOUNT OFF
END
GO