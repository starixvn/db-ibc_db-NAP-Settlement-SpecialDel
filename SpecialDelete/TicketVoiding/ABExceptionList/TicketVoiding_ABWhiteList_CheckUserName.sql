/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ABWhiteList_CheckUserName]
(
	  @UserNames	NVARCHAR(MAX) = ''
)
AS
/*
	Created by: July
	Task : [TVS] Implement AB Whitelist
	DB: DBCTG/bodb02

	Revisions:
		- 20211004@July: Create new SP - Check validation username [Redmine:#161659]
		- 20211021@Max: Tuning [Redmine: #161659]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20210420@July: TVS - Support AB Exclusion by sub issue type [Redmine:#170771]

	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @InvalidUserNames	NVARCHAR(2000) = ''
			,@ExistedUserNames  NVARCHAR(2000) = ''

	CREATE TABLE #tmpUserName (Username NVARCHAR(30))
	CREATE TABLE #tmpInvalidUserNames (Username NVARCHAR(30), InValid TINYINT) --1: Invalid UserNames, 2: Username already exists

	INSERT INTO #tmpUserName (Username)
	SELECT DISTINCT value
	FROM STRING_SPLIT(@UserNames, ',')
	WHERE value <> ''

	INSERT INTO #tmpInvalidUserNames (Username , InValid)
	SELECT  l.username
			,CASE WHEN ci.custid IS NULL THEN 1
				  WHEN ci.custid IS NOT NULL AND (ci.roleid NOT IN (1,2,3,4) OR s.isActive = 0) THEN 1
				  WHEN ab.Custid IS NOT NULL THEN 2
				ELSE 0 END
	FROM #tmpUserName l
		LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON ci.username = l.Username
		LEFT JOIN CustDB.dbo.Customer c WITH (NOLOCK) ON c.custid = ci.custid
		LEFT JOIN CustDB.dbo.Site s WITH (NOLOCK) ON c.site = s.site
		LEFT JOIN dbo.TicketVoiding_ABWhiteList ab WITH (NOLOCK) ON c.custid = ab.Custid

	SET @InvalidUserNames = STUFF((SELECT  ',' + Username
								  FROM #tmpInvalidUserNames
								  WHERE InValid = 1 
								  FOR XML PATH ('')),1,1,'')

	SET @ExistedUserNames = STUFF((SELECT  ',' + Username
								  FROM #tmpInvalidUserNames
								  WHERE InValid = 2
								  FOR XML PATH ('')),1,1,'')
	
	SELECT @InvalidUserNames AS InvalidUserNames
		  ,@ExistedUserNames AS ExistedUserNames

	DROP TABLE #tmpUserName

	SET NOCOUNT OFF
END
GO
