/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ABWhiteList_Select]
(
	 @UserName			VARCHAR(30) = NULL
	,@Level				VARCHAR(5)
	,@Sites				VARCHAR(MAX)
	,@SubTypes			VARCHAR(100)  = NULL
	,@VoidVIP			VARCHAR(10)	  = NULL
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
		- 20210412@July: TVS - Support AB Exclusion by sub issue type [Redmine:#170771]

	Param's Explanation:
		+ @Level: All - 0, Super - 4, Master - 3, Agent - 2, Member - 1
		+ @VoidVIP: 1 - Yes, 0 - No, -1 - N/A (apply for Credit sites)
		+ @SubTypes: All - 0,27,41,28,42,.... | 0 - (Blank), 27,41 - Abnormal, 28,42 - Group Betting, ...
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @roleid TINYINT
	SET @roleid = CAST( @Level AS TINYINT)

	CREATE TABLE #tmpSite (SiteId INT, SiteName NVARCHAR(50))
	CREATE TABLE #tmpABWhiteList (CustId INT, Username VARCHAR(30), [Level] TINYINT,  [Site] NVARCHAR(50), AddedDate DATETIME, AddedBy VARCHAR(30), AllowVoidSubType VARCHAR(100), IsAllowVoidVip SMALLINT)
	CREATE TABLE #tmpABWhiteList_Result (CustId INT, Username VARCHAR(30), [Level] TINYINT,  [Site] NVARCHAR(50), AddedDate DATETIME, AddedBy VARCHAR(30), SubTypeName VARCHAR(1000), IsAllowVoidVip SMALLINT)

	INSERT INTO #tmpSite (SiteId, SiteName)
	SELECT e.siteid, e.site
	FROM STRING_SPLIT(@Sites, ',') s
		INNER JOIN CustDB.dbo.Site e WITH(NOLOCK)	
			ON CAST(s.value AS INT) = e.siteid	
	
	DECLARE @tmpVoidVIP TABLE (isvip SMALLINT)
	INSERT INTO @tmpVoidVIP (isvip)
	SELECT value AS isvip
	FROM STRING_SPLIT(@VoidVIP, ',') 

	DECLARE @tmpSubtype TABLE (SubtypeId TINYINT)
	INSERT INTO @tmpSubtype (SubtypeId)
	SELECT value AS SubtypeId
	FROM STRING_SPLIT(ISNULL(@SubTypes,0), ',') 

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

	INSERT INTO #tmpABWhiteList (CustId, Username, [Level], [Site], AddedDate, AddedBy, AllowVoidSubType, IsAllowVoidVip)
	SELECT DISTINCT a.Custid
		 , c.username AS Username
		 , a.LevelId AS [Level]
		 , s.SiteName AS [Site]
		 , a.CreatedDate AS AddedDate
		 , u.username AS AddedBy
		 , a.AllowVoidSubType
		 , CASE WHEN dep.custid IS NOT NULL AND a.IsAllowVoidVip = 1 THEN  1 --Yes
				WHEN dep.custid IS NOT NULL AND ISNULL(a.IsAllowVoidVip,0) = 0 THEN  0 --No
				ELSE -1 --N/A
			END AS IsAllowVoidVip
	FROM dbo.TicketVoiding_ABWhiteList a WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = a.Custid 
		INNER JOIN #tmpSite s ON s.SiteId = a.SiteId
		INNER JOIN CustDB.dbo.Customer u WITH(NOLOCK) ON u.custid = a.CreateBy
		LEFT JOIN CustDB.dbo.Dep_CustSuper dep WITH(NOLOCK) ON c.srecommend = dep.custid
		CROSS APPLY (
				SELECT value AS SubType
				FROM STRING_SPLIT(ISNULL(a.AllowVoidSubType,0), ',') 
			)xSub
	WHERE (c.UserName = @UserName OR ISNULL(@UserName,'') = '')
		AND (a.LevelId = @roleid OR @roleid = 0)
		AND xSub.SubType IN (SELECT SubtypeId FROM @tmpSubtype)

	INSERT INTO #tmpABWhiteList_Result (CustId, Username, [Level], [Site], AddedDate, AddedBy, SubTypeName, IsAllowVoidVip)
	SELECT DISTINCT ab.CustId
		  ,ab.Username
		  ,ab.[Level]
		  ,ab.[Site]
		  ,ab.AddedDate
		  ,ab.AddedBy
		  ,CASE WHEN s.SubIssueTypeName IS NULL THEN '' ELSE s.SubIssueTypeName END AS SubTypeName
		  ,ab.IsAllowVoidVip
	FROM #tmpABWhiteList ab
		INNER JOIN @tmpVoidVIP vip ON ab.IsAllowVoidVip = vip.isvip
		CROSS APPLY (
				SELECT value AS SubType
				FROM STRING_SPLIT(ISNULL(ab.AllowVoidSubType,0), ',')
			)xSub
		OUTER APPLY (
				SELECT s.SubIssueTypeName 
				FROM dbo.TicketVoiding_SubIssueType s WITH(NOLOCK)
				WHERE s.SubIssueTypeId = xSub.SubType 
			)s	 

	SELECT DISTINCT CustId, Username, [Level], [Site], AddedDate, AddedBy, STUFF(t2.SubTypeName,1,1,'') AS SubTypeName, IsAllowVoidVip 
	FROM #tmpABWhiteList_Result t1
		CROSS APPLY (SELECT ', ' + CAST(SubTypeName AS VARCHAR(100))  
					FROM #tmpABWhiteList_Result t2
					WHERE t1.custid = t2.custid
					FOR XML PATH('')
				)t2(SubTypeName)	
	ORDER BY t1.AddedDate DESC, t1.Username ASC

	DROP TABLE #tmpSite
	DROP TABLE #tmpABWhiteList
	DROP TABLE #tmpABWhiteList_Result

	SET NOCOUNT OFF
END
GO
