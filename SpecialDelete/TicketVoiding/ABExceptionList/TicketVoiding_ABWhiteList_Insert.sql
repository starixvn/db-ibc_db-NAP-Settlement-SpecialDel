/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_ABWhiteList_Insert]
(
	  @UserNames			NVARCHAR(MAX) = ''
	 ,@SubTypes				VARCHAR(100)  = NULL
	 ,@VoidVIP				BIT			  = 0
	 ,@UserId				INT
	 ,@IP					VARCHAR(50) = NULL
)
AS
/*
	Created by: July
	Task : [TVS] Implement AB Whitelist
	DB: DBCTG/bodb02

	Revisions:
		- 20211004@July: Create new SP - Add New AB White List [Redmine:#161659]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20210412@July: TVS - Support AB Exclusion by sub issue type [Redmine:#170771]

	Param's Explanation:

		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
		   ,@EndTime			DATETIME
		   ,@LogData			VARCHAR(MAX)
		   ,@LogActionId		INT
		   ,@SB_Error			BIT

	CREATE TABLE #tmpUserName (Username NVARCHAR(30))
	CREATE TABLE #tmpInputUsernameList (custid INT, roleid TINYINT, [site] NVARCHAR(50))

	SET @StartTime = GETDATE()
	SET @LogActionId = 90004 
	SET @SB_Error = 0

	INSERT INTO #tmpUserName (Username)
	SELECT DISTINCT value AS Username
	FROM STRING_SPLIT(@UserNames, ',')
	WHERE value <> ''

	INSERT INTO #tmpInputUsernameList (custid, roleid, [site])
	SELECT ci.custid
		  ,ci.roleid
		  ,ci.site
	FROM #tmpUserName l	
		INNER JOIN CustDB.dbo.custInfo cf WITH (NOLOCK) ON l.Username = cf.username
		INNER JOIN CustDB.dbo.Customer ci WITH (NOLOCK) ON cf.custid = ci.custid
		LEFT JOIN dbo.TicketVoiding_ABWhiteList a WITH (NOLOCK) ON ci.custid = a.Custid
	WHERE a.custid IS NULL

	INSERT INTO dbo.TicketVoiding_ABWhiteList (Custid, LevelId, SiteId, CreateBy, LastModifiedBy, AllowVoidSubType, IsAllowVoidVip)
	SELECT i.custid, i.roleid, s.siteid, @UserId, @UserId, @SubTypes, @VoidVIP
	FROM #tmpInputUsernameList i
		INNER JOIN CustDB.dbo.Site s WITH (NOLOCK) ON i.site = s.site

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'	
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.'
							+ ', @UserNames: ' + CAST(@UserNames AS NVARCHAR(MAX))
							+ ', @SubTypes: ' + CASE WHEN @SubTypes IS NULL THEN 'NULL' ELSE CAST(@SubTypes AS VARCHAR(100)) END 
							+ ', @VoidVIP: ' + CAST(@VoidVIP AS VARCHAR(10))
							AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS NVARCHAR(MAX))


	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #tmpUserName
	DROP TABLE #tmpInputUsernameList

	SET NOCOUNT OFF
END
GO
