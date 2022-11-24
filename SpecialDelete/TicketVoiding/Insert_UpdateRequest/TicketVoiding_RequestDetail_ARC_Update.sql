/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_ARC_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT		= 17
	,@TransIds				VARCHAR(MAX) = NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@FilterBy				TINYINT = NULL
	,@SubIssueTypeId		TINYINT = NULL
	,@TransInfoJson			VARBINARY(MAX) = NULL
	,@IsEditRequest			INT
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype Archived ticket [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)
			,@OldTransIds 		 VARCHAR(MAX) = NULL

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

	CREATE TABLE #TempMatch (MatchId INT, IsOutright BIT)
	CREATE TABLE #TempEditMatchID ( MatchID INT, IsOutright BIT, IsFlag BIT) -- 0 Remove, 1 -- Add username -> match
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
	  ,custid	INT	
      ,bettype SMALLINT
      ,betid BIGINT
	  ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,custid	
		  ,bettype
		  ,betid
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT mid ,t ,c ,btype ,bid ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT
	) tbl

	INSERT INTO #TempMatch(MatchId, IsOutright)
	SELECT  DISTINCT matchid,
			CASE WHEN bettype <> 10 THEN 0 ELSE 1 END
	FROM #tmpTransInfo

	IF @IsEditRequest = 0
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM  #TempMatch WHERE IsOutright = 0)
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, SubIssueTypeId
					, FilterBy
			)
			SELECT @RequestId
					, t.MatchId 
					, ISNULL(m14.leagueid, 0) 
					, ISNULL(m14.homeid, 0) 
					, ISNULL(m14.awayid, 0) 
					, @SubIssueTypeId
					, @FilterBy
			FROM #TempMatch t
				LEFT JOIN dbo.match14 m14 WITH(NOLOCK) ON t.MatchId = m14.matchid
			WHERE t.IsOutright = 0

		END
		IF EXISTS (SELECT TOP 1 1 FROM #TempMatch WHERE IsOutright = 1) -- outright
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, SubIssueTypeId
					, FilterBy
			)
			SELECT @RequestId
					, t.MatchId 
					, ISNULL(o14.leagueid, 0) 
					, ISNULL(o14.teamid, 0) 
					, 0
					, @SubIssueTypeId
					, @FilterBy
			FROM #TempMatch t
				INNER JOIN dbo.outright14 o14 WITH(NOLOCK) ON t.MatchId = o14.orid
			WHERE t.IsOutright = 1
		END
	END
	ELSE IF @IsEditRequest = 1
	BEGIN
		SET @OldTransIds = STUFF((SELECT  ',' + CAST (TransId AS VARCHAR (20))
								  FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
								  WHERE RequestId = @RequestId
								  FOR XML PATH ('')),1,1,'')

		INSERT INTO #TempEditMatchID (MatchID, IsOutright, IsFlag)
		SELECT rd.MatchId,0, 0 -- remove match
		FROM  dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE  NOT EXISTS ( SELECT TOP 1 1 FROM #TempMatch m WHERE rd.MatchId = m.MatchID)
			 AND rd.RequestId = @RequestId
		UNION ALL
		SELECT m.MatchId,m.IsOutright, 1  -- add match
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
		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 0)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, SubIssueTypeId
				)
				SELECT @RequestId
					, e.MatchID
					, ISNULL(m14.leagueid, 0) 
					, ISNULL(m14.homeid, 0) 
					, ISNULL(m14.awayid, 0) 
					, @SubIssueTypeId
				FROM #TempEditMatchID e 
					LEFT JOIN dbo.match14 m14 WITH(NOLOCK) ON e.MatchID = m14.matchid 
				WHERE e.IsFlag = 1	AND e.IsOutright = 0	
		END  
		ELSE IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 1)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, SubIssueTypeId
				)
				SELECT @RequestId
					, e.MatchID
					, o14.leagueid
					, o14.teamid
					, 0
					, @SubIssueTypeId
				FROM #TempEditMatchID e 
					INNER JOIN dbo.outright14 o14 WITH(NOLOCK) ON e.MatchID = o14.orid
				WHERE e.IsFlag = 1	AND e.IsOutright = 1		
		END  

		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET   FilterBy =  @FilterBy
		WHERE	RequestId = @RequestId

	END

	IF @IsEditRequest = 1
	BEGIN
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single 
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, Bettype, BetId, CustId, SiteDBGroupID)
	SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, b14.transid, b14.matchid , rd.Id AS RequestDetailId, b14.bettype, b14.betid, b14.custid, b14.SiteDBGroupID
	FROM #tmpTransInfo b14
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON b14.matchid = rd.MatchId AND rd.RequestId = @RequestId

	-- Get content of log data 
	SET @LogDataContent = ''

	IF @IsEditRequest = 0
	BEGIN
		SET @LogDataContent += ' TransIds: ' + @TransIds
	END
	ELSE 
	BEGIN
		IF @TransIds <> @OldTransIds
		BEGIN
			SET @LogDataContent += ' Old TransIds: ' + @OldTransIds + ' New TransIds: ' + @TransIds
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
	
	DROP TABLE #TempEditMatchID
	DROP TABLE #TempMatch
	DROP TABLE #tmpTransInfo
	
END
GO