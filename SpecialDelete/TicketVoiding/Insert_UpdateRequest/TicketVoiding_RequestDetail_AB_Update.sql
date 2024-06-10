/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_AB_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@AbnormalBetInfo		VARCHAR(MAX) = NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT = 0
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype Abnormal bet & AB(real member) [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]
		- 20240315@July: [TVS] Abnormal Bet - Support void System Parlay tickets [Redmine: #196462]
		- 20240327@Max: [CTS] - [TVS] - Missing Void Info - Not auto-mark PA [Redmine: #201993]
		- 20240422@Max: [TVS] Abnormal Bet - Add single tickets of many matches to a request [Redmine: #196027]

	Param's explanation:
		+ @IssueTypeId : 11 - Abnormal Bet
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@LogDataContent	 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@OldSubIssueTypeId  SMALLINT
			,@OldMatchId		 INT
			,@OldTransIds 		 VARCHAR(MAX) = NULL
			,@row_count			 INT = 0
			,@Decompress_TransInfoJson NVARCHAR(MAX) = NULL
			,@TransIds				VARCHAR(MAX) = NULL
			,@FilterBy				TINYINT = NULL
			,@SubIssueTypeId		TINYINT = NULL
			,@AbnormalBetInfoXML	 XML = NULL	

	DECLARE @tmpMatchId_Info AS TABLE (MatchId INT, homeid INT, awayid INT, leagueid INT, sporttype SMALLINT, matchcode NVARCHAR(50))

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)

	CREATE TABLE #tmpTransInfo(
	   matchid			INT
	  ,transid			BIGINT
	  ,custid			INT	
      ,bettype			SMALLINT
      ,betid			BIGINT
	  ,IsMixParlay		BIT
	  ,SiteDBGroupID	SMALLINT
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

	SET @AbnormalBetInfoXML = CONVERT(XML, @AbnormalBetInfo)
	SELECT @TransIds = t.c.value('@TransIds','VARCHAR(MAX)')
		, @FilterBy = NULLIF(t.c.value('@FilterBy','TINYINT'),'')
		, @SubIssueTypeId = t.c.value('@SubIssueTypeId','TINYINT')
	FROM @AbnormalBetInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@AbnormalBetInfoXML = NULL))

	-- get match info
	IF @FilterBy IS NULL
	BEGIN
		INSERT INTO @tmpMatchId_Info (MatchId, homeid, awayid, leagueid)
		SELECT DISTINCT m.matchid, homeid, awayid, leagueid
		FROM #tmpTransInfo t 
			INNER JOIN dbo.match m WITH(NOLOCK) ON m.matchid = t.matchid

		UNION 
		SELECT DISTINCT m.matchid, homeid, awayid, leagueid
		FROM #tmpTransInfo t 
			INNER JOIN dbo.match14 m WITH(NOLOCK) ON m.matchid = t.matchid
	END
	ELSE
	BEGIN
		INSERT INTO @tmpMatchId_Info (MatchId)
		SELECT DISTINCT t.matchid
		FROM #tmpTransInfo t 
	END

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	IF @IsEditRequest = 1
	BEGIN
		DELETE dbo.TicketVoiding_RequestDetail 
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetail (
		RequestId
		, MatchId
		, LeagueId
		, HomeId
		, AwayId
		, RequestType
		, SubIssueTypeId
		, FilterBy
	)
	SELECT @RequestId
		, m.MatchId
		, m.leagueid
		, m.homeid
		, m.awayid
		, CASE WHEN @ActionId IN (4,8) THEN 1 ELSE 0 END
		, @SubIssueTypeId
		, @FilterBy
	FROM @tmpMatchId_Info m
	
	IF @IsEditRequest = 1
	BEGIN
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single 
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID)
	SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, s.transid, rd.MatchId, rd.Id AS RequestDetailId, s.bettype, s.betid, s.custid, s.SiteDBGroupID
	FROM #tmpTransInfo s
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
				ON rd.RequestId = @RequestId AND s.MatchId = rd.MatchId

	SET @row_count = @@ROWCOUNT

	UPDATE rd SET rd.SingleCount = @row_count
	FROM TicketVoiding_RequestDetail rd WITH (ROWLOCK, UPDLOCK)
	WHERE rd.RequestId = @RequestId

	-- Get content of log data 
	SET @LogDataContent = ''
	SET @LogDataContent += ' TransIds: ' + @TransIds + ', SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20))
	
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
	
	DROP TABLE #transIdTemp
	DROP TABLE #tmpTransInfo
END
GO