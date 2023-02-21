/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_DARC_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT	= 1
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@DARCInfo				VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT 
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype Danger Accepted & Red Card [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20221125@July: TVS - VAR message [Redmine: #178088]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]

	Param's explanation:
		+ @IssueTypeId: 1 - Danger Accepted, 10 - Red Card
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @DARCInfoXML		  XML = NULL
			,@topBatch			  INT = 4500
			,@SingleCount		  INT
		    ,@MainParlayCount	  INT

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
			,TypeAccept				VARCHAR(300)
			,SubIssueTypeId			SMALLINT
			)

	CREATE TABLE #tmpTransInfo(
			 matchid INT
			,transid BIGINT
			,Subtransid BIGINT
			,custid	INT	
			,bettype SMALLINT
			,betid BIGINT
			,IsMixParlay BIT
			,SiteDBGroupID SMALLINT
			,IsCancelCashOut BIT
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
		  ,IsCancelCashOut
		)
	SELECT mid ,t ,s_t ,c ,btype ,bid ,isP ,sitedb ,isCCO
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT, isCCO BIT
	) tbl

	SET @DARCInfoXML = CONVERT(XML, @DARCInfo)
	INSERT INTO #tblGetLogInfo( 
			RequestID				
			,MatchID				
			,FilterFromTransTime	
			,FilterToTransTime			
			,FilterBy				
			,SingleCount			
			,MainParlayCount		
			,VoidFromTime			
			,VoidToTime				
			,LiveScores					
			,TypeAccept
			,SubIssueTypeId
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
			,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
			,t.c.value('@FilterBy','TINYINT') AS FilterBy
			,t.c.value('@SingleCount','INT') AS SingleCount
			,t.c.value('@MainParlayCount','INT') AS MainParlayCount
			,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
			,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
			,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
			,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') + '" SA="' + t.c.value('@SATime','VARCHAR(10)') + 
				+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') 
				+ '" IsCheckedVar="' + CAST (t.c.value('@IsCheckedVar','BIT') AS VARCHAR(10))
				+ '" />' AS TypeAccept
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
	FROM @DARCInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@DARCInfoXML = NULL))

	IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL
		
		UPDATE	r
		SET	  FilterFromTransTime = l.FilterFromTransTime
			, FilterToTransTime = l.FilterToTransTime
			, FilterBy = l.FilterBy
			, SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, LiveHomeScore = l.LiveHomeScore
			, LiveAwayScore = l.LiveAwayScore
			, IssueDetail = l.LiveScores
			, TransIds = l.TypeAccept
			, SubIssueTypeId = l.SubIssueTypeId
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
		, FilterFromTransTime
		, FilterToTransTime
		, FilterBy
		, SingleCount
		, MainParlayCount
		, VoidFromTime
		, VoidToTime
		, LiveHomeScore
		, LiveAwayScore
		, IssueDetail
		, TransIds
		, SubIssueTypeId
		)
	SELECT @RequestId
		, l.MatchID
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.kickofftime
		, l.FilterFromTransTime
		, l.FilterToTransTime
		, l.FilterBy
		, l.SingleCount
		, l.MainParlayCount
		, l.VoidFromTime
		, l.VoidToTime
		, l.LiveHomeScore
		, l.LiveAwayScore
		, l.LiveScores
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

	SELECT @SingleCount = SUM(SingleCount)
		  ,@MainParlayCount = SUM(MainParlayCount)
	FROM #tblGetLogInfo

	IF @SingleCount > 0
	BEGIN
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
				 , DELETED.IsCancelCashOut
			INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID, IsCancelCO)
			FROM #tmpTransInfo d
				INNER JOIN dbo.TicketVoiding_RequestDetail rd ON rd.RequestId = @RequestId AND rd.MatchId = d.matchid
			WHERE d.IsMixParlay = 0

			IF @@ROWCOUNT < @topBatch BREAK
			
			WAITFOR DELAY '00:00:00.180'
		END
	END

	WHILE (1=1) AND @IsEditRequest = 1
	BEGIN
		DELETE TOP(@topBatch) s 
		FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay s
		WHERE s.RequestId = @RequestId

		IF @@ROWCOUNT < @topBatch BREAK

		WAITFOR DELAY '00:00:00.100'
	END

	IF @MainParlayCount > 0
	BEGIN
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
	END

	-- Get content of log data 
	SET @LogDataContent = ''
	SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20)) 
							+ ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							+ ', FilterFrom: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) 
							+ ', FilterTo: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
							+ ', SingleCount: ' + CAST(l.SingleCount AS VARCHAR(20))
							+ ', MainParlayCount: ' + CAST(l.MainParlayCount AS VARCHAR(20))
							+ ', VoidFrom: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidTo: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							+ ', TypeAccept: ' + l.TypeAccept
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
	
	DROP TABLE #tblGetLogInfo
	DROP TABLE #tmpTransInfo
	
END
GO