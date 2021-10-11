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

	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @InvalidUserNames	NVARCHAR(MAX) = ''

	CREATE TABLE #tmpUserName (Username NVARCHAR(30))

	INSERT INTO #tmpUserName (Username)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@UserNames, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	SET @InvalidUserNames = STUFF((SELECT  ',' + l.username
								  FROM #tmpUserName l
									LEFT JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON l.username = ci.username
								  WHERE ci.custid IS NULL	
								  FOR XML PATH ('')),1,1,'')

	SELECT @InvalidUserNames AS InvalidUserNames

	DROP TABLE #tmpUserName

	SET NOCOUNT OFF
END
GO
