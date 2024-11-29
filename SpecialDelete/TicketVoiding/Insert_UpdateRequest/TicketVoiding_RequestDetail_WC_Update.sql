/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_WC_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT = 3
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT 
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype Wrong score [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20221125@July: TVS - VAR message [Redmine: #178088]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230324@Max: [TVS] Manage Request enhancement - Phase 13 [Redmine: #185237]
		- 20230405@July: [TVS] Enhance auto cancel cash out for TVS [Redmine: #186417]
		- 20240124@Max: [TVS] Display more info in the warning message for existing tickets in other requests [Redmine: #199907]
		- 20240701@July: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
		- 20241113@July: Enhance the way to add request for suspenders - [Redmine: #185495]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @WrongScoreInfoXML		  XML = NULL
			,@MatchId				INT
			,@FilterBy				TINYINT = NULL
			,@actualscore			VARCHAR(50)

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
			,IssueDetail			NVARCHAR(MAX)
			,TypeAccept				VARCHAR(2000)
			,SubIssueTypeId			SMALLINT
			)
	
	CREATE TABLE #tmpTransInfo(
			 matchid		INT
			,transid		BIGINT
			,Subtransid		BIGINT
			,custid			INT	
			,bettype		SMALLINT
			,betid			BIGINT
			,VoidFromTime	DATETIME
			,VoidToTime     DATETIME
			,IsMixParlay	BIT
			,SiteDBGroupID  SMALLINT
			,IsCancelCashOut BIT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,Subtransid
		  ,custid	
		  ,bettype
		  ,betid
		  ,VoidFromTime	
		  ,VoidToTime  
		  ,IsMixParlay
		  ,SiteDBGroupID
		  ,IsCancelCashOut
		)
	SELECT mid ,t ,s_t ,c ,btype ,bid , vft, vtt ,isP ,sitedb ,isCCO
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT, vft DATETIME , vtt DATETIME ,isP BIT ,sitedb SMALLINT, isCCO BIT
	) tbl

	SET @WrongScoreInfoXML = CONVERT(xml, @WrongScoreInfo)
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
			,LiveHomeScore
			,LiveAwayScore
			,IssueDetail 
			,SubIssueTypeId
			,TypeAccept
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
			,t.c.value('@LiveHomeScore','INT') AS LiveHomeScore
			,t.c.value('@LiveAwayScore','INT') AS LiveAwayScore
			,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') 
				+ ';Act:' + t.c.value('@ActualScore','VARCHAR(50)') 
				+ ';TvDetectionValue:' + t.c.value('@TvDetectionValue','VARCHAR(10)') --0 - uncheck; 1-slow; 2-fast
				+ ';ServiceAcceptTime:' + t.c.value('@ServiceAcceptTime','VARCHAR(50)')
				+ ';ActualTime:' + t.c.value('@ActualTime','VARCHAR(50)')
				+ ';MinuteOffset:' + t.c.value('@MinuteOffset','VARCHAR(10)')
				+ ';SecondOffset:' + t.c.value('@SecondOffset','VARCHAR(10)')
			AS IssueDetail
			,t.c.value('@SubIssueTypeId','INT') AS SubIssueTypeId
			,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') + '" SA="' + t.c.value('@SATime','VARCHAR(10)') + 
			+ '" ScoreId="' + t.c.value('@ScoreId','VARCHAR(20)') 
			+ '" IsCheckedVar="' + CAST (t.c.value('@IsCheckedVar','BIT') AS VARCHAR(10))
			+ '" MinTime="' + ISNULL(CONVERT(VARCHAR(50),NULLIF(t.c.value('@MinTime','DATETIME'),''), 121),'')
			+ '" MinType="' + t.c.value('@MinType','VARCHAR(10)') 
			+ '" MinTransId="' + t.c.value('@MinTransId','VARCHAR(50)') 
			+ '" ActionType="' + t.c.value('@ActionType','VARCHAR(100)')
			+ '" />' AS TypeAccept
	FROM @WrongScoreInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))

    IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID 
				AND rd.LiveHomeScore = t.LiveHomeScore 
				AND rd.LiveAwayScore = t.LiveAwayScore
				AND rd.FilterFromTransTime = t.FilterFromTransTime
				AND rd.FilterToTransTime = t.FilterToTransTime
				AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL

		UPDATE	r
		SET	  FilterFromTransTime = l.FilterFromTransTime
			, FilterToTransTime = l.FilterToTransTime
			, SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, LiveHomeScore = l.LiveHomeScore
			, LiveAwayScore = l.LiveAwayScore
			, IssueDetail = l.IssueDetail
			, SubIssueTypeId = l.SubIssueTypeId
			, TransIds = l.TypeAccept
			, FilterBy = l.FilterBy
		FROM dbo.TicketVoiding_RequestDetail r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblGetLogInfo l ON l.RequestID = r.RequestId AND l.MatchID = r.MatchId AND r.LiveHomeScore = l.LiveHomeScore AND r.LiveAwayScore = l.LiveAwayScore
														AND r.FilterFromTransTime = l.FilterFromTransTime
														AND r.FilterToTransTime = l.FilterToTransTime

	END

	INSERT INTO dbo.TicketVoiding_RequestDetail (
		RequestId
		, MatchId
		, LeagueId
		, HomeId
		, AwayId
		, Sporttype
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
		, m.sporttype
		, l.FilterFromTransTime
		, l.FilterToTransTime
		, l.FilterBy
		, l.SingleCount
		, l.MainParlayCount
		, l.VoidFromTime
		, l.VoidToTime
		, l.LiveHomeScore
		, l.LiveAwayScore
		, l.IssueDetail
		, l.TypeAccept
		, l.SubIssueTypeId
	FROM #tblGetLogInfo l
		INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
		LEFT JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = l.RequestID AND rd.MatchId = l.MatchID 
														AND rd.LiveHomeScore = l.LiveHomeScore AND rd.LiveAwayScore = l.LiveAwayScore
														AND rd.FilterFromTransTime = l.FilterFromTransTime
														AND rd.FilterToTransTime = l.FilterToTransTime
	WHERE rd.RequestId IS NULL

	IF @IsEditRequest = 1
	BEGIN			
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single 
		WHERE RequestId = @RequestId	
		
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay
		WHERE RequestId = @RequestId
	END
	
	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID, IsCancelCO)
	SELECT @RequestId
		, @IssueTypeId
		, rd.SubIssueTypeId
		, t.TransId
		, t.MatchId
		, rd.Id AS RequestDetailId
		, t.bettype
		, t.betid
		, t.CustId
		, t.SiteDBGroupID
		, t.IsCancelCashOut
	FROM #tmpTransInfo t
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId AND rd.VoidFromTime = t.VoidFromTime AND rd.VoidToTime = t.VoidToTime
	WHERE rd.RequestId = @RequestId  AND t.IsMixParlay = 0

	INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId, SiteDBGroupID)
	SELECT @RequestId
		, @IssueTypeId
		, rd.SubIssueTypeId
		, t.Subtransid
		, t.MatchId
		, rd.Id AS RequestDetailId
		, t.TransId
		, t.SiteDBGroupID
	FROM #tmpTransInfo t
		INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId AND rd.VoidFromTime = t.VoidFromTime AND rd.VoidToTime = t.VoidToTime
	WHERE rd.RequestId = @RequestId AND t.IsMixParlay = 1

	-- Get content of log data 
	SET @LogDataContent = ''
	SELECT @actualscore = SUBSTRING(l.IssueDetail, CHARINDEX(';Act:',l.IssueDetail) + 5, LEN(l.IssueDetail))
		, @MatchId = l.MatchID
		, @FilterBy = l.FilterBy
	FROM #tblGetLogInfo l

	IF @FilterBy <> 2
	BEGIN
		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20))
							+', Actual Score: ' + @actualscore
							+', Wrong Score: ' 
		SELECT @LogDataContent = @LogDataContent
								+', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
								+ CAST(l.LiveHomeScore AS VARCHAR(5)) +'-'
								+ CAST(l.LiveAwayScore AS VARCHAR(5))+' ('
								+ 'From Time: '+ CONVERT(VARCHAR(30),l.FilterFromTransTime, 21)  +' - '
								+ 'To Time: '+ CONVERT(VARCHAR(30),l.FilterToTransTime, 21) +'); '
		FROM #tblGetLogInfo l
	END
	ELSE
	BEGIN
		SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20)) 
							+ ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							+ ', Actual Score: ' + @actualscore
							+ ', FilterFrom: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) 
							+ ', FilterTo: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21) 
							+ ', VoidFrom: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidTo: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							+ ', TypeAccept: ' + l.TypeAccept
		FROM #tblGetLogInfo l
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
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	

	DROP TABLE #tblGetLogInfo
	DROP TABLE #tmpTransInfo
END
GO