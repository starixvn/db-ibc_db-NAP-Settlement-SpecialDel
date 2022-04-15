/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_ABWhiteList_Select]
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
		+ @SubTypes: All - 0,1,2,3,..., 0 - (Blank), 1 - Abnormal, 2 - Group Betting, 3...
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @roleid TINYINT
	SET @roleid = CAST( @Level AS TINYINT)

	CREATE TABLE #tmpSite (SiteId INT, SiteName NVARCHAR(50))
	CREATE TABLE #tmpABWhiteList (CustId INT, Username VARCHAR(30), [Level] TINYINT,  [Site] NVARCHAR(50), AddedDate DATETIME, AddedBy VARCHAR(30), SubType VARCHAR(100), VoidVIP SMALLINT)
	CREATE TABLE #tmpABWhiteList_Result (CustId INT, Username VARCHAR(30), [Level] TINYINT,  [Site] NVARCHAR(50), AddedDate DATETIME, AddedBy VARCHAR(30), SubTypeName VARCHAR(1000), VoidVIP SMALLINT)

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
	FROM STRING_SPLIT(@SubTypes, ',') 

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

	INSERT INTO #tmpABWhiteList (CustId, Username, [Level], [Site], AddedDate, AddedBy, SubType, VoidVIP)
	SELECT a.Custid
		 , c.username AS Username
		 , a.LevelId AS [Level]
		 , s.SiteName AS [Site]
		 , a.CreatedDate AS AddedDate
		 , u.username AS AddedBy
		 , a.SubType
		 , CASE WHEN dep.custid IS NOT NULL AND a.VoidVIP = 1 THEN  1 --Yes
				WHEN dep.custid IS NOT NULL AND a.VoidVIP = 0 THEN  0 --No
				ELSE -1 --N/A
			END AS VoidVIP
	FROM dbo.TicketVoiding_ABWhiteList a WITH(NOLOCK)
		INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON c.custid = a.Custid 
		INNER JOIN #tmpSite s ON s.SiteId = a.SiteId
		INNER JOIN CustDB.dbo.Customer u WITH(NOLOCK) ON u.custid = a.CreateBy
		LEFT JOIN CustDB.dbo.Dep_CustSuper dep WITH(NOLOCK) ON c.srecommend = dep.custid
	WHERE (c.UserName = @UserName OR ISNULL(@UserName,'') = '')
		AND (a.LevelId = @roleid OR @roleid = 0)
	ORDER BY a.CreatedDate DESC, c.username ASC

	INSERT INTO #tmpABWhiteList_Result (CustId, Username, [Level], [Site], AddedDate, AddedBy, SubTypeName, VoidVIP)
	SELECT ab.CustId
		  ,ab.Username
		  ,ab.[Level]
		  ,ab.[Site]
		  ,ab.AddedDate
		  ,ab.AddedBy
		  ,CASE WHEN f.SubTypeName IS NULL THEN '(Blank)' ELSE f.SubTypeName END AS SubTypeName
		  ,ab.VoidVIP
	FROM #tmpABWhiteList ab
		OUTER APPLY (
				SELECT value AS SubType
				FROM STRING_SPLIT(ab.SubType, ',')
			)xSub
		OUTER APPLY (
				SELECT f.SubTypeName 
				FROM dbo.f_TVS_CheckingSubTypeAllowVoiding() f
				WHERE f.SubTypeId = xSub.SubType 
			)f	 
	WHERE ab.VoidVIP IN (SELECT isvip FROM @tmpVoidVIP)
		AND xSub.SubType IN (SELECT SubtypeId FROM @tmpSubtype)

	SELECT DISTINCT CustId, Username, [Level], [Site], AddedDate, AddedBy, STUFF(t2.SubTypeName,1,1,''), VoidVIP 
	FROM #tmpABWhiteList_Result t1
		CROSS APPLY (SELECT ', ' + CAST(SubTypeName AS VARCHAR(100))  
					FROM #tmpABWhiteList_Result t2
					WHERE t1.custid = t2.custid
					FOR XML PATH('')
				)t2(SubTypeName)	

	DROP TABLE #tmpSite
	DROP TABLE #tmpABWhiteList
	DROP TABLE #tmpABWhiteList_Result

	SET NOCOUNT OFF
END
GO
