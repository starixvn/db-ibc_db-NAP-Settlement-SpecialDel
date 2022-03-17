/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ABWhiteList_Select]
(
	 @UserName			VARCHAR(30) = NULL
	,@Level				VARCHAR(5)
	,@Sites				VARCHAR(MAX)
	,@InvalidUsername   VARCHAR(30) = '' OUTPUT
)
AS
/*
	Created by: July
	Task : [TVS] Implement AB Whitelist
	DB: DBTXN/bodb02

	Revisions:
		- 20211001@July: Create new SP - Search [Redmine:#161659]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]

	Param's Explanation:
		+ @Level: All - 0, Super - 4, Master - 3, Agent - 2, Member - 1
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @roleid TINYINT
	SET @roleid = CAST( @Level AS TINYINT)

	CREATE TABLE #tmpSite (SiteId INT, SiteName NVARCHAR(50))
	CREATE TABLE #tmpABWhiteList (CustId INT, Username VARCHAR(30), [Level] TINYINT,  [Site] NVARCHAR(50), AddedDate DATETIME, AddedBy VARCHAR(30))

	INSERT INTO #tmpSite (SiteId, SiteName)
	SELECT e.siteid, e.site
	FROM STRING_SPLIT(@Sites, ',') s
		INNER JOIN CustDB.dbo.Site e WITH(NOLOCK)	
			ON CAST(s.value AS INT) = e.siteid	
	
	IF @UserName IS NOT NULL
	BEGIN
		SET @InvalidUsername = (SELECT username FROM  CustDB.dbo.Customer WITH(NOLOCK) WHERE username = @UserName)			
		IF @InvalidUsername IS NOT NULL
		BEGIN
			SET @InvalidUsername = NULL
		END
		ELSE 
		BEGIN
			SET @InvalidUsername = @UserName
			RETURN;
		END
	END

	INSERT INTO #tmpABWhiteList (CustId, Username, [Level], [Site], AddedDate, AddedBy)
	SELECT a.Custid
		 , c.username AS Username
		 , a.LevelId AS [Level]
		 , s.SiteName AS [Site]
		 , a.CreatedDate AS AddedDate
		 , u.username AS AddedBy
	FROM dbo.TicketVoiding_ABWhiteList a WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = a.Custid 
		INNER JOIN #tmpSite s ON s.SiteId = a.SiteId
		INNER JOIN CustDB.dbo.Customer u WITH(NOLOCK) ON u.custid = a.CreateBy
	WHERE (c.UserName = @UserName OR ISNULL(@UserName,'') = '')
		AND (a.LevelId = @roleid OR @roleid = 0)
	ORDER BY a.CreatedDate DESC, c.username ASC

	SELECT CustId, Username, [Level], [Site], AddedDate, AddedBy 
	FROM #tmpABWhiteList

	DROP TABLE #tmpSite
	DROP TABLE #tmpABWhiteList

	SET NOCOUNT OFF
END
GO
