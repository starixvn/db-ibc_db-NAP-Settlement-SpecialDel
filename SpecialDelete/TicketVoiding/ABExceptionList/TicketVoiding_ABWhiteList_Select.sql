/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
	DB: DBCTG/bodb02

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
	CREATE TABLE #tmpABWhiteList (CustId INT, Username VARCHAR(30), [Level] TINYINT,  [Site] NVARCHAR(50), AddedDate DATETIME, AddedBy VARCHAR(30), AllowVoidSubType VARCHAR(100), SubTypeName VARCHAR(1000), IsAllowVoidVip SMALLINT)

	INSERT INTO #tmpSite (SiteId, SiteName)
	SELECT e.siteid, e.site
	FROM STRING_SPLIT(@Sites, ',') s
		INNER JOIN CustDB.dbo.Site e WITH(NOLOCK)	
			ON CAST(s.value AS INT) = e.siteid	
	
	DECLARE @tmpVoidVIP TABLE (VoidVip SMALLINT)
	INSERT INTO @tmpVoidVIP (VoidVip)
	SELECT value AS VoidVip
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

	INSERT INTO #tmpABWhiteList (CustId, Username, [Level], [Site], AddedDate, AddedBy, AllowVoidSubType, SubTypeName, IsAllowVoidVip)
	SELECT DISTINCT a.Custid
		 , c.username AS Username
		 , a.LevelId AS [Level]
		 , s.SiteName AS [Site]
		 , a.CreatedDate AS AddedDate
		 , u.username AS AddedBy
		 , a.AllowVoidSubType
		 , CASE WHEN su.SubIssueTypeName IS NULL THEN '' ELSE su.SubIssueTypeName END AS SubTypeName
		 , depvip.IsAllowVoidVip AS IsAllowVoidVip
	FROM dbo.TicketVoiding_ABWhiteList a WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = a.Custid 
		INNER JOIN #tmpSite s ON s.SiteId = a.SiteId
		INNER JOIN CustDB.dbo.Customer u WITH(NOLOCK) ON u.custid = a.CreateBy
		LEFT JOIN CustDB.dbo.Dep_CustSuper dep WITH(NOLOCK) ON c.srecommend = dep.custid
		CROSS APPLY (
			SELECT CASE WHEN dep.custid IS NOT NULL AND a.IsAllowVoidVip = 1 THEN  1
				        WHEN dep.custid IS NOT NULL AND ISNULL(a.IsAllowVoidVip,0) = 0 THEN  0 
				  ELSE -1 
			 END AS IsAllowVoidVip
		)depvip
		CROSS APPLY (
			SELECT value AS SubtypeId FROM STRING_SPLIT(ISNULL(a.AllowVoidSubType,0), ',') 
		)xSub_Filter
		CROSS APPLY (
			SELECT value AS SubtypeId FROM STRING_SPLIT(ISNULL(a.AllowVoidSubType,0), ',') 
		)xSub_GetName
		OUTER APPLY (
				SELECT s.SubIssueTypeName 
				FROM dbo.TicketVoiding_SubIssueType s WITH(NOLOCK)
				WHERE s.SubIssueTypeId = xSub_GetName.SubtypeId 
			)su
	WHERE (c.UserName = @UserName OR ISNULL(@UserName,'') = '')
		AND (a.LevelId = @roleid OR @roleid = 0)
		AND xSub_Filter.SubtypeId IN (SELECT SubtypeId FROM @tmpSubtype)
		AND depvip.IsAllowVoidVip IN (SELECT VoidVip FROM @tmpVoidVIP)
	ORDER BY SubTypeName ASC

	SELECT DISTINCT CustId, Username, [Level], [Site], AddedDate, AddedBy, STUFF(t2.SubTypeName,1,1,'') AS SubTypeName, IsAllowVoidVip 
	FROM #tmpABWhiteList t1
		CROSS APPLY (SELECT ', ' + CAST(SubTypeName AS VARCHAR(100))  
					FROM #tmpABWhiteList t2
					WHERE t1.custid = t2.custid
					FOR XML PATH('')
				)t2(SubTypeName)	
	ORDER BY t1.AddedDate DESC, t1.Username ASC

	DROP TABLE #tmpSite
	DROP TABLE #tmpABWhiteList

	SET NOCOUNT OFF
END
GO
