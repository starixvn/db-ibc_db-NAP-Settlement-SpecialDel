/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_ACC_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@SubIssueTypeId		TINYINT = NULL
	,@AbnormalAccountInfo	NVARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT = 0
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype Abnormal account [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230517@July: [TVS] Abnormal Account - Void archived tickets [Redmine: #188152]
		- 20231102@Max: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240327@Max: [CTS] - [TVS] - Missing Void Info - Not auto-mark PA [Redmine: #201993]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	@AbnormalAccountInfoXML  XML = NULL
			,@OldUserNames			 NVARCHAR(MAX) = NULL
			,@OldFromDate			 DATETIME     = NULL
			,@OldToDate				 DATETIME     = NULL
			,@OldProductIds			 VARCHAR(50)  = NULL
			,@OldStatusIds			 VARCHAR(50)  = NULL
			,@OldSubIssueTypeId		 SMALLINT
			,@UserNames				 NVARCHAR(MAX) = NULL
			,@ProductIds			 VARCHAR(50) = NULL
			,@StatusIds				 VARCHAR(50) = NULL
			,@FromDate				 DATETIME = NULL
			,@ToDate				 DATETIME = NULL
			,@maxdate 				 DATETIME = '9999-01-01'
			,@row_count				 INT = 0

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #TempMatch (MatchId INT, IsOutright BIT, IsVoid14 BIT)
	CREATE TABLE #TempEditMatchID ( MatchID INT, IsOutright BIT, IsVoid14 BIT DEFAULT(0), IsFlag BIT) -- 0 Remove, 1 -- Add username -> match

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
	  ,custid	INT	
      ,bettype SMALLINT
      ,betid BIGINT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	  ,IsVoid14 BIT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,custid	
		  ,bettype
		  ,betid
		  ,IsMixParlay
		  ,SiteDBGroupID
		  ,IsVoid14
		)
	SELECT mid ,t ,c ,btype ,bid ,isP ,sitedb ,isV14
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT ,isV14 BIT
	) tbl

	SET @AbnormalAccountInfoXML = CONVERT(XML, @AbnormalAccountInfo)
	SELECT @UserNames = t.c.value('@Usernames','NVARCHAR(MAX)') 
			,@ProductIds = t.c.value('@ProductIds','VARCHAR(50)')
			,@StatusIds = t.c.value('@StatusIds','VARCHAR(50)')
			,@FromDate = t.c.value('@FromDate','DATETIME')
			,@ToDate = CASE WHEN t.c.value('@ToDate','DATETIME') = '1900-01-01 00:00:00.000' THEN @maxdate ELSE t.c.value('@ToDate','DATETIME') END
	FROM @AbnormalAccountInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AbnormalAccountInfoXML = NULL))

	INSERT INTO #TempMatch(MatchId, IsOutright, IsVoid14)
	SELECT  DISTINCT matchid,
			CASE WHEN bettype <> 10 THEN 0 ELSE 1 END,
			IsVoid14
	FROM #tmpTransInfo

	IF @IsEditRequest = 0
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM  #TempMatch WHERE MatchId IN (9,29,2799,10449)) --parlay
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT DISTINCT @RequestId
					, MatchId 
					, 0
					, 0
					, 0
			FROM #TempMatch
			WHERE matchid IN (9,29,2799,10449)
		END
		
		IF EXISTS ( SELECT TOP 1 1 FROM  #TempMatch WHERE IsOutright = 0 AND IsVoid14 = 0) --match
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
					, t.MatchId 
					, ISNULL(m.leagueid, 0) 
					, ISNULL(m.homeid, 0) 
					, ISNULL(m.awayid, 0) 
			FROM #TempMatch t
				INNER JOIN dbo.match m WITH(NOLOCK) ON t.MatchId = m.matchid 
			WHERE t.IsOutright = 0 AND t.IsVoid14 = 0

		END
		
		IF EXISTS ( SELECT TOP 1 1 FROM  #TempMatch WHERE IsOutright = 0 AND IsVoid14 = 1) --match14
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
					, t.MatchId 
					, ISNULL(m.leagueid, 0) 
					, ISNULL(m.homeid, 0) 
					, ISNULL(m.awayid, 0) 
			FROM #TempMatch t
				INNER JOIN dbo.match14 m WITH(NOLOCK) ON t.MatchId = m.matchid
			WHERE t.IsOutright = 0 AND t.IsVoid14 = 1
		END
		
		IF EXISTS (SELECT TOP 1 1 FROM #TempMatch WHERE IsOutright = 1 AND IsVoid14 = 0) -- outright
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
					, t.MatchId 
					, ISNULL(m.leagueid, 0) 
					, ISNULL(m.teamid, 0) 
					, 0
			FROM #TempMatch t
				INNER JOIN dbo.outright m WITH(NOLOCK) ON t.MatchId = m.orid
			WHERE t.IsOutright = 1 AND t.IsVoid14 = 0
		END

		IF EXISTS (SELECT TOP 1 1 FROM #TempMatch WHERE IsOutright = 1 AND IsVoid14 = 1) -- outright14
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
					, t.MatchId 
					, ISNULL(m.leagueid, 0) 
					, ISNULL(m.teamid, 0) 
					, 0
			FROM #TempMatch t
				INNER JOIN dbo.outright14 m WITH(NOLOCK) ON t.MatchId = m.orid
			WHERE t.IsOutright = 1 AND t.IsVoid14 = 1
		END
		
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET   UserNames =  @UserNames
				, ProductIds = @ProductIds
				, TicketStatusIds = @StatusIds
				, FromWinlostDate = @FromDate
				, ToWinlostDate = @ToDate
				, RequestType = CASE WHEN @ActionId IN (4,10) THEN 1 ELSE 0 END
				, SubIssueTypeId = @SubIssueTypeId
		WHERE	RequestId = @RequestId
	END
	ELSE IF @IsEditRequest = 1
	BEGIN
		SELECT   @OldUserNames	 = UserNames
				, @OldFromDate	 = FromWinlostDate
				, @OldToDate	 = ToWinlostDate
				, @OldProductIds = ProductIds
				, @OldStatusIds  = TicketStatusIds
				, @OldSubIssueTypeId = SubIssueTypeId
		FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK)
		WHERE RequestId = @RequestId

		INSERT INTO #TempEditMatchID (MatchID, IsOutright, IsVoid14, IsFlag)
		SELECT rd.MatchId,0,0, 0 -- remove match
		FROM  dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE  NOT EXISTS ( SELECT TOP 1 1 FROM #TempMatch m WHERE rd.MatchId = m.MatchID)
			 AND rd.RequestId = @RequestId
		UNION ALL
		SELECT m.MatchId ,m.IsOutright , m.IsVoid14, 1  -- add match
		FROM  #TempMatch m
		OUTER APPLY  (
					SELECT rd.MatchId
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					WHERE m.MatchID = rd.MatchId AND rd.RequestId = @RequestId
			)tmp
		WHERE tmp.MatchId IS NULL

		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 0 )
		BEGIN
				DELETE rd
				FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					INNER JOIN #TempEditMatchID e ON  rd.MatchId = e.MatchID
				WHERE rd.RequestId = @RequestId AND e.IsFlag = 0
		END
		
		IF EXISTS ( SELECT TOP 1 1 FROM  #TempEditMatchID WHERE MatchId IN (9,29,2799,10449)) --parlay
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT DISTINCT @RequestId
					, MatchId 
					, 0
					, 0
					, 0
			FROM #TempEditMatchID
			WHERE matchid IN (9,29,2799,10449)
		END

		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 0 AND IsVoid14 = 0) --match
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
				, e.MatchID
				, ISNULL(m.leagueid, 0) 
				, ISNULL(m.homeid, 0) 
				, ISNULL(m.awayid, 0) 
			FROM #TempEditMatchID e 
				INNER JOIN dbo.match m WITH(NOLOCK) ON e.MatchID = m.matchid 
			WHERE e.IsFlag = 1	AND e.IsOutright = 0 AND IsVoid14 = 0	
		END  

		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 0 AND IsVoid14 = 1) --match14
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
				, e.MatchID
				, ISNULL(m.leagueid, 0) 
				, ISNULL(m.homeid, 0) 
				, ISNULL(m.awayid, 0) 
			FROM #TempEditMatchID e 
				INNER JOIN dbo.match14 m WITH(NOLOCK) ON e.MatchID = m.matchid 
			WHERE e.IsFlag = 1	AND e.IsOutright = 0 AND IsVoid14 = 1	
		END  

		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 1 AND IsVoid14 = 0) --outright
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
				, e.MatchID
				, m.leagueid
				, m.teamid
				, 0
			FROM #TempEditMatchID e 
				INNER JOIN dbo.outright m WITH(NOLOCK) ON e.MatchID = m.orid
			WHERE e.IsFlag = 1	AND e.IsOutright = 1 AND e.IsVoid14 = 0	
		END  
		
		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 1 AND IsVoid14 = 1) --outright14
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
			SELECT @RequestId
				, e.MatchID
				, m.leagueid
				, m.teamid
				, 0
			FROM #TempEditMatchID e 
				INNER JOIN dbo.outright m WITH(NOLOCK) ON e.MatchID = m.orid
			WHERE e.IsFlag = 1	AND e.IsOutright = 1 AND e.IsVoid14 = 0	
		END  

		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET   UserNames =  @UserNames
				, ProductIds = @ProductIds
				, TicketStatusIds = @StatusIds
				, FromWinlostDate = @FromDate
				, ToWinlostDate = @ToDate
				, RequestType = CASE WHEN @ActionId IN (4,10) THEN 1 ELSE 0 END
				, SubIssueTypeId = @SubIssueTypeId
		WHERE	RequestId = @RequestId

	END

	IF @IsEditRequest = 1
	BEGIN
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID)
	SELECT @RequestId
		,@IssueTypeId
		,@SubIssueTypeId
		,s.transid 
		,s.matchid
		,rd.Id AS RequestDetailId
		,s.bettype
		,s.betid
		,s.custid
		,s.SiteDBGroupID
	FROM #tmpTransInfo s
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
				ON rd.RequestId = @RequestId AND s.MatchId = rd.MatchId

	SET @row_count = @@ROWCOUNT

	UPDATE rd SET rd.SingleCount = @row_count
	FROM TicketVoiding_RequestDetail rd WITH (ROWLOCK, UPDLOCK)
	WHERE rd.RequestId = @RequestId

	-- Get content of log data 
	SET @LogDataContent = ''
	IF @IsEditRequest = 0
	BEGIN
		SET @LogDataContent += ' SubIssueTypeID: '+ CAST(@SubIssueTypeId AS VARCHAR(20))
						    + ', Username: ' + CAST(@UserNames AS NVARCHAR(MAX)) 
						    + ', ProductIds: '+ CAST(@ProductIds AS VARCHAR(50))
						    + ', StatusIds: '+ CAST(@StatusIds AS VARCHAR(50))
						    + ', From Date: '+ CONVERT(VARCHAR(10), @FromDate, 23)
						    + ', To Date: '+ CASE WHEN @ToDate IS NOT NULL THEN CONVERT(VARCHAR(10), @ToDate, 23) ELSE 'NULL' END
	END
	ELSE
	BEGIN
		IF @OldSubIssueTypeId <> @SubIssueTypeId
		BEGIN
			SET @LogDataContent += ' Old SubIssueTypeID: ' +  CAST(@OldSubIssueTypeId AS VARCHAR(20)) + ' New SubIssueTypeID: ' +  CAST(@SubIssueTypeId AS VARCHAR(20))
		END
		IF @OldUserNames <> @UserNames
		BEGIN
			SET @LogDataContent += ' Old Usernames: ' + @OldUserNames + ' New Usernames: ' + @UserNames
		END
		IF @OldProductIds <> @ProductIds
		BEGIN
			SET @LogDataContent += ' Old ProductIds: ' + @OldProductIds + ' New ProductIds: ' + @ProductIds
		END
		IF @OldStatusIds <> @StatusIds
		BEGIN
			SET @LogDataContent += ' Old StatusIds: ' + @OldStatusIds + ' New StatusIds: ' + @StatusIds
		END
		IF @OldFromDate <> @FromDate
		BEGIN
			SET @LogDataContent += ' Old FromDate: ' + CONVERT(VARCHAR(10), @OldFromDate, 23) + ' New FromDate: ' + CONVERT(VARCHAR(10), @FromDate, 23)
		END
		IF @OldToDate <> @ToDate
		BEGIN
			SET @LogDataContent += ' Old ToDate: ' + CONVERT(VARCHAR(10), @OldToDate, 23) + ' New ToDate: ' + CONVERT(VARCHAR(10), @ToDate, 23)
		END
	END
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,CASE WHEN @IsEditRequest = 0 THEN 90001 ELSE 90003 END AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
							+ @LogDataContent
						AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #TempMatch
	DROP TABLE #tmpTransInfo
	DROP TABLE #TempEditMatchID
END
GO