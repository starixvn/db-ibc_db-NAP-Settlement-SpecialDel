/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestDetail_KO_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@SubIssueTypeId		TINYINT = NULL
	,@KickOffInfo			VARCHAR(MAX) = NULL	
	,@TransInfo				XML  = NULL
	,@IsEditRequest			INT = 0
)
AS
/*	
	Created by: July
	Date 20220808
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype Early KO & Wrong KO [Redmine: #175412]

	Param's explanation:
		+ @IssueTypeId : 8 - Early Kick Off, 9 - Wrong Kick Off Time
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)
			,@MatchId			 INT = 0
			,@KickOffTime		 DATETIME = NULL
			,@KickOffInfoXML	 XML = NULL	
			,@OldKickOffTime	 DATETIME = NULL
			,@RequestDetailId	 INT

	SET @KickOffInfoXML = CONVERT(XML, @KickOffInfo)
	SELECT @MatchId = t.c.value('@MatchId','INT') 
		  ,@KickOffTime = t.c.value('@KickOffTime','DATETIME')
	FROM @KickOffInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@KickOffInfoXML = NULL))

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
      ,Subtransid BIGINT
	  ,custid INT	
      ,refno BIGINT
      ,bettype SMALLINT
      ,betid BIGINT
      ,IsMixParlay BIT
	  ,SiteDBGroupID SMALLINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,Subtransid
		  ,custid
		  ,refno
		  ,bettype
		  ,betid
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT t.c.value('@mid','INT') AS matchid
			,t.c.value('@t','BIGINT') AS transid
			,t.c.value('@s_t','BIGINT') AS Subtransid
			,t.c.value('@c','INT') AS custid
			,t.c.value('@ref','BIGINT') AS refno
			,t.c.value('@btype','SMALLINT') AS bettype
			,t.c.value('@bid','BIGINT') AS betid
			,t.c.value('@isP','BIT') AS IsMixParlay
			,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
	FROM @TransInfo.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

	IF @IsEditRequest = 0 
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (
			RequestId
			, MatchId
			, LeagueId
			, HomeId
			, AwayId
			, KickOffTime
			, RequestType
			, SubIssueTypeId
		)
		SELECT @RequestId
			, @MatchId
			, leagueid
			, homeid
			, awayid
			, @KickOffTime
			, 0
			, @SubIssueTypeId
		FROM dbo.match WITH(NOLOCK)
		WHERE matchid = @MatchId
		SET @RequestDetailId = SCOPE_IDENTITY()
	END
	ELSE 
	BEGIN
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET	@OldKickOffTime = KickOffTime
				,KickOffTime = ISNULL(@KickOffTime, KickOffTime)
				,SubIssueTypeId = ISNULL(@SubIssueTypeId, SubIssueTypeId)
				,@RequestDetailId = Id
		WHERE	RequestId = @RequestId
				AND MatchId = @MatchId
	END
	
	IF @IsEditRequest = 1
	BEGIN
		DELETE dbo.TicketVoiding_RequestDetailTicket_Single
		WHERE RequestId = @RequestId

		DELETE dbo.TicketVoiding_RequestDetailTicket_SubParlay
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID)
	SELECT @RequestId
		,@IssueTypeId
		,@SubIssueTypeId
		,s.transid
		,s.matchid
		,@RequestDetailId
		,s.bettype
		,s.betid
		,s.custid
		,s.SiteDBGroupID
	FROM #tmpTransInfo s
	WHERE s.IsMixParlay = 0

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId, SiteDBGroupID)
	SELECT @RequestId
			, @IssueTypeId
			, @SubIssueTypeId
			, s.SubTransid
			, s.matchid
			, @RequestDetailId
			, s.transid AS MainTransId
			, s.SiteDBGroupID
	FROM #tmpTransInfo s
	WHERE s.IsMixParlay = 1
	
	-- Get content of log data 
	SET @LogDataContent = ''
	IF @IsEditRequest = 0
	BEGIN
		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
	END
	ELSE
	BEGIN
		IF @OldKickOffTime <> @KickOffTime
		BEGIN
		SET @LogDataContent += ' Old KickOffTime: ' + CONVERT(VARCHAR(30), @OldKickOffTime, 21) + ' New KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
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
	

END
GO