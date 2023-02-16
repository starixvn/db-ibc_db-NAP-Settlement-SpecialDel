/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_AB_Update]
(
	@RequestId				INT
	,@MatchId				INT = 0
	,@IssueTypeId			TINYINT		= NULL
	,@TransIds				VARCHAR(MAX) = NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@FilterBy				TINYINT = NULL
	,@SubIssueTypeId		TINYINT = NULL
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

	Param's explanation:
		+ @IssueTypeId : 11 - Abnormal Bet, 15 - AB(real member)
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@LogDataContent	 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LeagueId			 INT = 0
			,@HomeId			 INT = 0
			,@AwayId			 INT = 0
			,@OldSubIssueTypeId  SMALLINT
			,@OldMatchId		 INT
			,@OldTransIds 		 VARCHAR(MAX) = NULL
			,@RequestDetailId	 INT

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)

	CREATE TABLE #tmpTransInfo(
	   matchid			INT
	  ,transid			BIGINT
	  ,custid			INT	
      ,bettype			SMALLINT
	  ,betteam			NVARCHAR(10)
      ,betid			BIGINT
	  ,IsMixParlay		BIT
	  ,SiteDBGroupID	SMALLINT
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
		)
	SELECT mid ,t ,c ,btype ,bteam ,bid ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,c INT ,btype SMALLINT ,bteam NVARCHAR(10) ,bid BIGINT ,isP BIT ,sitedb SMALLINT
	) tbl

	-- get match info
	SELECT	@LeagueId = leagueid
			,@HomeId = homeid
			,@AwayId = awayid
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchId

	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT value 
	FROM STRING_SPLIT(@TransIds, ',')
	WHERE value <> ''

	IF @IsEditRequest = 0 
	BEGIN
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
			, @MatchId
			, @LeagueId
			, @HomeId
			, @AwayId
			, CASE WHEN @ActionId IN (4,6,7,8) THEN 1 ELSE 0 END
			, @SubIssueTypeId
			, CASE WHEN @IssueTypeId = 11 THEN @FilterBy ELSE NULL END

		SET @RequestDetailId = SCOPE_IDENTITY()
	END
	ELSE
	BEGIN
		SET @OldTransIds = STUFF((SELECT  ',' + CAST (TransId AS VARCHAR (20))
								  FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
								  WHERE RequestId = @RequestId
								  FOR XML PATH ('')),1,1,'')

		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET	LeagueId = ISNULL(@LeagueId, LeagueId)
				,@OldMatchId = MatchId
				,MatchId = ISNULL(@MatchId, MatchId)
				,HomeId = ISNULL(@HomeId, HomeId)
				,AwayId = ISNULL(@AwayId, AwayId)
				,RequestType = CASE WHEN @ActionId IN (4,6,7,8) THEN 1 ELSE 0 END
				,@OldSubIssueTypeId = SubIssueTypeId
				,SubIssueTypeId = ISNULL(@SubIssueTypeId, SubIssueTypeId)
				,@RequestDetailId =Id
		WHERE	RequestId = @RequestId
	END
	
	IF @IsEditRequest = 1
	BEGIN
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single 
		WHERE RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID)
	SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, t.transid, @MatchId, @RequestDetailId AS RequestDetailId, tmp.bettype, tmp.betid, tmp.custid, tmp.SiteDBGroupID
	FROM #transIdTemp t
		CROSS APPLY (
					SELECT b.bettype, b.betid, b.custid, b.SiteDBGroupID
					FROM #tmpTransInfo b
					WHERE b.matchid = @MatchId
						AND t.transid = b.transid
						AND 1 = CASE WHEN @FilterBy IS NULL THEN 1
									 WHEN @FilterBy = 1 AND b.betteam = '1' THEN 1 ELSE 0 END
					)tmp

	-- Get content of log data 
	SET @LogDataContent = ''
	IF @IsEditRequest = 0
	BEGIN
		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', TransIds: ' + @TransIds + ', SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20))
	END
	ELSE
	BEGIN
		IF @MatchId <> @OldMatchId
		BEGIN
			SET @LogDataContent += ' Old MatchId: ' + CAST(@OldMatchId AS VARCHAR(20)) + ' New MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', '
		END
		IF @TransIds <> @OldTransIds
		BEGIN
			SET @LogDataContent += ' Old TransIds: ' + @OldTransIds + ' New TransIds: ' + @TransIds
		END
		IF @SubIssueTypeId <> @OldSubIssueTypeId
		BEGIN
			SET @LogDataContent += ' Old SubIssueTypeId: ' + CAST(@OldSubIssueTypeId AS VARCHAR(20))  + ' New SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20))
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
	
	DROP TABLE #transIdTemp
	DROP TABLE #tmpTransInfo
END
GO