/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_KO_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@KickOffInfo			VARCHAR(MAX) = NULL	
	,@TransInfoJson			VARCHAR(MAX) = NULL	
	,@IsEditRequest			INT = 0
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype Early KO & Wrong KO [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20231016@Max: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]

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
			,@KickOffInfoXML	 XML = NULL	
			,@topBatch			  INT = 4500
					
	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #tblGetLogInfo (
			 RequestID				INT
			,MatchID				INT
			,FilterFromTransTime	DATETIME 
			,FilterToTransTime		DATETIME 
			,FilterBy				TINYINT 
			,SingleCount			INT 
			,MainParlayCount		INT 
			,VoidFromTime			DATETIME 
			,VoidToTime				DATETIME
			,LiveHomeScore			INT
			,LiveAwayScore			INT
			,LiveScores				NVARCHAR(300)
			,TypeAccept				VARCHAR(2000)
			,SubIssueTypeId			SMALLINT
			,KickOffTime		 DATETIME
		)

	SET @KickOffInfoXML = CONVERT(XML, @KickOffInfo)
	INSERT INTO #tblGetLogInfo( 
			RequestID				
			,MatchID	
			,TypeAccept	
			,SubIssueTypeId
			,KickOffTime
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,'<r IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') 
				+ '" />' AS TypeAccept
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,t.c.value('@KickOffTime','DATETIME')
	FROM @KickOffInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@KickOffInfoXML = NULL))

	CREATE TABLE #tmpTransInfo(
	   matchid INT
	  ,transid BIGINT
      ,Subtransid BIGINT
	  ,custid INT	
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
		  ,bettype
		  ,betid
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT mid ,t ,s_t ,c ,btype ,bid ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT
	) tbl

	IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL
		
		UPDATE	r
		SET	  KickOffTime = l.KickOffTime
			, SubIssueTypeId = l.SubIssueTypeId
			, TransIds = l.TypeAccept
		FROM dbo.TicketVoiding_RequestDetail r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblGetLogInfo l ON l.RequestID = r.RequestId AND l.MatchID = r.MatchId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetail (
		RequestId
		, MatchId
		, LeagueId
		, HomeId
		, AwayId
		, KickOffTime
		, TransIds
		, SubIssueTypeId
		)
	SELECT @RequestId
		, l.MatchID
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.kickofftime
		, l.TypeAccept
		, l.SubIssueTypeId
	FROM #tblGetLogInfo l
		INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
		LEFT JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = l.RequestID AND rd.MatchId = l.MatchID
	WHERE rd.RequestId IS NULL
	
	WHILE (1=1) AND @IsEditRequest = 1
	BEGIN
		DELETE TOP(@topBatch) s 
		FROM dbo.TicketVoiding_RequestDetailTicket_Single s
		WHERE s.RequestId = @RequestId

		IF @@ROWCOUNT < @topBatch BREAK

		WAITFOR DELAY '00:00:00.100'
	END

	WHILE (1=1)
	BEGIN
		DELETE TOP(@topBatch) d
		OUTPUT @RequestId
				, @IssueTypeId
				, rd.SubIssueTypeId
				, DELETED.TransId
				, DELETED.MatchId
				, rd.Id
				, DELETED.bettype
				, DELETED.betid
				, DELETED.CustId
				, DELETED.SiteDBGroupID
		INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID)
		FROM #tmpTransInfo d
			INNER JOIN dbo.TicketVoiding_RequestDetail rd ON rd.RequestId = @RequestId AND rd.MatchId = d.matchid
		WHERE d.IsMixParlay = 0

		IF @@ROWCOUNT < @topBatch BREAK
			
		WAITFOR DELAY '00:00:00.180'
	END

	WHILE (1=1) AND @IsEditRequest = 1
	BEGIN
		DELETE TOP(@topBatch) s 
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s
		WHERE s.RequestId = @RequestId

		IF @@ROWCOUNT < @topBatch BREAK

		WAITFOR DELAY '00:00:00.100'
	END

	WHILE (1=1)
	BEGIN
		DELETE TOP(@topBatch) d
		OUTPUT @RequestId
			, @IssueTypeId
			, rd.SubIssueTypeId
			, DELETED.Subtransid
			, DELETED.MatchId
			, rd.Id
			, DELETED.TransId
			, DELETED.SiteDBGroupID
		INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId, SiteDBGroupID)
		FROM #tmpTransInfo d
			INNER JOIN dbo.TicketVoiding_RequestDetail rd ON rd.RequestId = @RequestId AND rd.MatchId = d.matchid
		WHERE d.IsMixParlay = 1

		IF @@ROWCOUNT < @topBatch BREAK
			
		WAITFOR DELAY '00:00:00.180'
	END
	
	-- Get content of log data 
	SET @LogDataContent = ''
	SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20)) 
							+ ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							+ ', KickOffTime: ' + CONVERT(VARCHAR(30), L.KickOffTime, 21)
							FROM #tblGetLogInfo l
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