/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ABWhiteList_CheckUserName]
(
	  @UserNames	NVARCHAR(MAX) = ''
)
AS
/*
	Created by: July
	Task : [TVS] Implement AB Whitelist
	DB: DBTXN/bodb02

	Revisions:
		- 20211004@July: Create new SP - Check validation username [Redmine:#161659]
		- 20211021@Max: Tuning [Redmine: #161659]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @InvalidUserNames	NVARCHAR(MAX) = ''

	CREATE TABLE #tmpUserName (Username NVARCHAR(30))

	INSERT INTO #tmpUserName (Username)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@UserNames, ',')
	WHERE value <> ''

	SET @InvalidUserNames = STUFF((SELECT  ',' + l.username
								  FROM #tmpUserName l
									LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON ci.username = l.Username
									LEFT JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = ci.custid
									LEFT JOIN CustDB.dbo.Site s WITH (NOLOCK) ON c.site = s.site
								  WHERE 1 = CASE WHEN ci.custid IS NULL THEN 1
												 WHEN ci.custid IS NOT NULL AND (ci.roleid NOT IN (1,2,3,4) OR s.isActive = 0) THEN 1
												 ELSE 0 END
								  FOR XML PATH ('')),1,1,'')

	SELECT @InvalidUserNames AS InvalidUserNames

	DROP TABLE #tmpUserName

	SET NOCOUNT OFF
END
GO
