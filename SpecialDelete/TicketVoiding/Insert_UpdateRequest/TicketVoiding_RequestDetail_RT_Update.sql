/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_RT_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT	= 22
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@RecoverTicketInfo		VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT
)
AS
/*	
	Created by: 20240102@July
	Task: [TVS] Recover Ticket issue type [Redmine: #196020]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20240102@July: Create new SP [Redmine:#196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240701@July: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]

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
			
	DECLARE  @RecoverTicketInfoXML  XML = NULL
			,@TransIds				VARCHAR(MAX) = NULL
			,@ProductIds			VARCHAR(50) = NULL
			,@FilterBy				TINYINT = NULL -- (NULL: sing & mix parlay, 3: subparlay)
			,@SubIssueTypeId		TINYINT = NULL

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #tmpMatch (MatchId INT, IsOutright BIT, IsMoved14 BIT)
	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
	  ,Subtransid BIGINT
	  ,custid INT	
      ,bettype SMALLINT
      ,betid BIGINT
	  ,IsMixParlay BIT
	  ,IsMoved14 BIT
	  ,SiteDBGroupID SMALLINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,Subtransid
		  ,custid	
		  ,bettype
		  ,betid
		  ,IsMixParlay
		  ,IsMoved14
		  ,SiteDBGroupID
		)
	SELECT mid ,t ,s_t ,c ,btype ,bid ,isP ,isM ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,isM BIT,sitedb SMALLINT
	) tbl

	SET @RecoverTicketInfoXML = CONVERT(XML, @RecoverTicketInfo)
	SELECT @TransIds = t.c.value('@TransIds','NVARCHAR(MAX)') 
		  ,@ProductIds = t.c.value('@ProductIds','VARCHAR(50)')
		  ,@FilterBy = CASE WHEN t.c.value('@FilterBy','TINYINT') = 0 THEN NULL ELSE t.c.value('@FilterBy','TINYINT') END
		  ,@SubIssueTypeId = t.c.value('@SubIssueTypeId','TINYINT')
	FROM @RecoverTicketInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@RecoverTicketInfoXML = NULL))

	INSERT INTO #tmpMatch(MatchId, IsOutright, IsMoved14)
	SELECT  DISTINCT matchid,
			CASE WHEN bettype <> 10 THEN 0 ELSE 1 END,
			IsMoved14
	FROM #tmpTransInfo

	IF @IsEditRequest = 1
	BEGIN
		SET @OldTransIds = STUFF((SELECT  ',' + CAST (TransId AS VARCHAR (50))
								  FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
								  WHERE RequestId = @RequestId
								  FOR XML PATH ('')),1,1,'')
		
		DELETE FROM dbo.TicketVoiding_RequestDetail
		WHERE RequestId = @RequestId

		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single 
		WHERE RequestId = @RequestId
	END

	IF EXISTS ( SELECT TOP 1 1 FROM  #tmpMatch WHERE MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))) --parlay
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId)
		SELECT DISTINCT @RequestId
				, MatchId 
				, 0
				, 0
				, 0
		FROM #tmpMatch
		WHERE matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
	END
		
	IF EXISTS ( SELECT TOP 1 1 FROM  #tmpMatch WHERE IsOutright = 0 AND IsMoved14 = 0) --match
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, Sporttype)
		SELECT @RequestId
				, t.MatchId 
				, ISNULL(m.leagueid, 0) 
				, ISNULL(m.homeid, 0) 
				, ISNULL(m.awayid, 0) 
				, m.sporttype
		FROM #tmpMatch t
			INNER JOIN dbo.match m WITH(NOLOCK) ON t.MatchId = m.matchid 
		WHERE t.IsOutright = 0 AND t.IsMoved14 = 0

	END
		
	IF EXISTS ( SELECT TOP 1 1 FROM  #tmpMatch WHERE IsOutright = 0 AND IsMoved14 = 1) --match14
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, Sporttype)
		SELECT @RequestId
				, t.MatchId 
				, ISNULL(m.leagueid, 0) 
				, ISNULL(m.homeid, 0) 
				, ISNULL(m.awayid, 0) 
				, m.sporttype
		FROM #tmpMatch t
			INNER JOIN dbo.match14 m WITH(NOLOCK) ON t.MatchId = m.matchid
		WHERE t.IsOutright = 0 AND t.IsMoved14 = 1
	END
		
	IF EXISTS (SELECT TOP 1 1 FROM #tmpMatch WHERE IsOutright = 1 AND IsMoved14 = 0) -- outright
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, Sporttype)
		SELECT @RequestId
				, t.MatchId 
				, ISNULL(m.leagueid, 0) 
				, ISNULL(m.teamid, 0) 
				, 0
				, l.sporttype
		FROM #tmpMatch t
			INNER JOIN dbo.outright m WITH(NOLOCK) ON t.MatchId = m.orid
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE t.IsOutright = 1 AND t.IsMoved14 = 0
	END

	IF EXISTS (SELECT TOP 1 1 FROM #tmpMatch WHERE IsOutright = 1 AND IsMoved14 = 1) -- outright14
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, Sporttype)
		SELECT @RequestId
				, t.MatchId 
				, ISNULL(m.leagueid, 0) 
				, ISNULL(m.teamid, 0) 
				, 0
				, l.sporttype
		FROM #tmpMatch t
			INNER JOIN dbo.outright14 m WITH(NOLOCK) ON t.MatchId = m.orid
			INNER JOIN dbo.league l WITH (NOLOCK) ON m.leagueid = l.leagueid
		WHERE t.IsOutright = 1 AND t.IsMoved14 = 1
	END
		
	UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
		SET  ProductIds = @ProductIds
			, SubIssueTypeId = @SubIssueTypeId
			, FilterBy = @FilterBy
	WHERE	RequestId = @RequestId

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, Bettype, BetId, CustId, SiteDBGroupID)
	SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, b.transid, b.matchid , rd.Id AS RequestDetailId, b.bettype, b.betid, b.custid, b.SiteDBGroupID
	FROM #tmpTransInfo b
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
			ON b.matchid = rd.MatchId AND rd.RequestId = @RequestId

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
	
	DROP TABLE #tmpMatch
	DROP TABLE #tmpTransInfo
	
END
GO