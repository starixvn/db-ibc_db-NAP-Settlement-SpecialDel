/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_DT_Update]
(
	 @RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@DuplicateTicketsInfo	VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT = 0 
)
AS
/*	
	Created by:20230717@Max
	Task: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230717@Max: Create new SP [Redmine:#187835]
		- 20231031@Max: [TVS] - Hot fix - Duplicate ticket missing void parlay virtual sport [Redmine: #196241]
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
			,@LogDataContent	 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@RequestDetailId	 INT
			,@MatchId			INT
			,@SubIssueTypeId  SMALLINT
			,@FilterBy			TINYINT
			,@DuplicateTicketsInfoXML XML = NULL	
			,@Decompress_TransInfoJson NVARCHAR(MAX) = NULL
			,@xmlTransIds XML = NULL
			,@OrgTransIds	VARCHAR(MAX) = ''

	DECLARE @tmp_TransIds AS TABLE (Remained VARCHAR(MAX), Voided VARCHAR(MAX))

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #tmpTransInfo(
	   matchid			INT
	  ,transid			BIGINT
	  ,custid			INT	
      ,bettype			SMALLINT
	  ,betteam			NVARCHAR(10)
      ,betid			BIGINT
	  ,IsMixParlay		BIT
	  ,SiteDBGroupID	SMALLINT
	  ,IsOrg			SMALLINT
	  ,DuplicateGroup BIGINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,custid	
		  ,bettype
		  ,betteam
		  ,betid
		  ,IsMixParlay
		  ,SiteDBGroupID
		  ,IsOrg
		  ,DuplicateGroup
		)
	SELECT mid ,t ,c ,btype ,bteam ,bid ,isP ,sitedb, isO, dgr
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,c INT ,btype SMALLINT ,bteam NVARCHAR(10) ,bid BIGINT ,isP BIT ,sitedb SMALLINT, isO SMALLINT, dgr BIGINT
	) tbl

	SET @DuplicateTicketsInfoXML = CONVERT(XML, @DuplicateTicketsInfo)
	
	SELECT @MatchId = t.c.value('@MatchId','INT')
			,@SubIssueTypeId = t.c.value('@SubIssueTypeId','SMALLINT') 
			,@FilterBy = NULLIF(t.c.value('@FilterBy','TINYINT'),0)
			,@OrgTransIds = t.c.value('@OrgTransIds','VARCHAR(MAX)')
	FROM @DuplicateTicketsInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@DuplicateTicketsInfoXML = NULL))

	IF @ActionId = 4
	BEGIN
		INSERT INTO @tmp_TransIds (Remained, Voided)
		SELECT  CASE WHEN r.IsOrg = 1 THEN CONVERT(VARCHAR(50), r.transid) ELSE @OrgTransIds END,
				STUFF(
						(SELECT ', ' + CAST(transid AS VARCHAR(MAX)) 
					FROM #tmpTransInfo t
					WHERE (t.IsOrg <> 1) AND t.DuplicateGroup = r.DuplicateGroup
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,2,''
				) AS TransIds
		FROM #tmpTransInfo r
		WHERE (r.IsOrg = 1)
		ORDER BY DuplicateGroup
	END
	ELSE
	BEGIN
		INSERT INTO @tmp_TransIds (Remained, Voided)
		SELECT  @OrgTransIds,
				STUFF(
						(SELECT ', ' + CAST(transid AS VARCHAR(MAX)) 
					FROM #tmpTransInfo t
					FOR XML PATH(''),TYPE).value('(./text())[1]','VARCHAR(MAX)') ,1,2,''
				) AS TransIds
	END

	SELECT @xmlTransIds = (SELECT t.Remained AS '@OrgTransIds'
								, t.Voided AS '@VoidedTransIds'
							FROM @tmp_TransIds t
							FOR XML PATH('r'), ROOT('root')
						)

	IF @IsEditRequest = 1 
	BEGIN
		DELETE FROM dbo.TicketVoiding_RequestDetail
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetail (
		RequestId
		, MatchId
		, LeagueId
		, HomeId
		, AwayId
		, Sporttype
		, RequestType
		, SubIssueTypeId
		, FilterBy
		, TransIds
	)
	SELECT @RequestId
		, @MatchId
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.sporttype
		, CASE WHEN @ActionId IN (4,6,7,8) THEN 1 ELSE 0 END
		, @SubIssueTypeId
		, @FilterBy
		, CONVERT(VARCHAR(MAX), @xmlTransIds)
	FROM (
		SELECT m.leagueid, m.homeid, m.awayid, m.sporttype
		FROM dbo.match m WITH (NOLOCK)
		WHERE m.matchid = @MatchId

		UNION
		SELECT m.League3rdId, m.homeid, m.awayid, m.sporttype
		FROM dbo.Match3rd m WITH (NOLOCK)
		WHERE m.Match3rdId = @MatchId
	)m

	SET @RequestDetailId = SCOPE_IDENTITY()
	
	IF @IsEditRequest = 1
	BEGIN
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single 
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID)
	SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, t.transid, @MatchId, @RequestDetailId AS RequestDetailId, t.bettype, t.betid, t.custid, t.SiteDBGroupID
	FROM #tmpTransInfo t
	WHERE matchid = @MatchId
		AND 1 = CASE WHEN @FilterBy IS NULL THEN 1
					 WHEN @FilterBy = 1 AND t.bettype IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END
		AND IsOrg <> 1

	-- Get content of log data 
	SET @LogDataContent = ''
	SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) 
							+ ', SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20)) 
							+ ', TransIds: ' + CONVERT(VARCHAR(MAX), @xmlTransIds)
	
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
	
	DROP TABLE #tmpTransInfo
END
GO