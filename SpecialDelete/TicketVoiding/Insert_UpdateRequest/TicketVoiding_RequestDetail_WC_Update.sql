/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_WC_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT = 3
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
	,@TransInfoJson			VARBINARY(MAX) = NULL
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
			,@SingleCount			INT 
		    ,@MainParlayCount		INT

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

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
			,TypeAccept				VARCHAR(50)
			,SubIssueTypeId			SMALLINT
			)
	CREATE TABLE #TVSTicketBets (MatchId INT, TransId BIGINT, SubTransId BIGINT, VoidFromTime DATETIME, VoidToTime DATETIME, bettype SMALLINT, betid BIGINT, CustId INT, IsMixParlay BIT, SiteDBGroupID SMALLINT)
	CREATE TABLE #tmpTransInfo(
			 matchid		INT
			,transid		BIGINT
			,Subtransid		BIGINT
			,custid			INT	
			,bettype		SMALLINT
			,betid			BIGINT
			,transdate		DATETIME
			,checktime      DATETIME
			,IsMixParlay	BIT
			,SiteDBGroupID  SMALLINT
	)
	INSERT INTO #tmpTransInfo( 
		   matchid
		  ,transid 
		  ,Subtransid
		  ,custid	
		  ,bettype
		  ,betid
		  ,transdate	
		  ,checktime  
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT mid ,t ,s_t ,c ,btype ,bid ,tdate, CASE WHEN checkt = '1900-01-01 00:00:00.000' THEN NULL ELSE checkt END AS checkt ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT, tdate DATETIME , checkt DATETIME ,isP BIT ,sitedb SMALLINT
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
			,LiveScores --ActualScore, LiveScores for WC
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
			,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' + t.c.value('@ActualScore','VARCHAR(50)') AS ActualScore
			,t.c.value('@SubIssueTypeId','INT') AS SubIssueTypeId
			,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') + '" SA="' + t.c.value('@SATime','VARCHAR(10)') + 
			+ '" ScoreId="' + t.c.value('@ScoreId','VARCHAR(20)') 
			+ '" IsCheckedVar="' + CAST (t.c.value('@IsCheckedVar','BIT') AS VARCHAR(10))
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
			, IssueDetail = l.LiveScores
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
	INSERT INTO #TVSTicketBets (MatchId, TransId, SubTransId, VoidFromTime, VoidToTime, bettype, betid, CustId, IsMixParlay, SiteDBGroupID)
	SELECT b.matchid
			, b.transid
			, b.Subtransid
			, d.VoidFromTime
			, d.VoidToTime
			, b.bettype
			, b.betid
			, b.custid
			, b.IsMixParlay
			,b.SiteDBGroupID
		FROM #tmpTransInfo b 
			INNER JOIN #tblGetLogInfo d ON d.MatchID = b.matchid
		WHERE 1 = CASE WHEN d.FilterBy = 1 AND b.transdate BETWEEN d.VoidFromTime AND d.VoidToTime THEN 1
						 WHEN d.FilterBy = 2 AND ISNULL(b.checktime, b.transdate) BETWEEN d.VoidFromTime AND d.VoidToTime THEN 1
						 WHEN d.FilterBy = 4 AND ((b.checktime BETWEEN d.VoidFromTime AND d.VoidToTime) OR (b.transdate BETWEEN d.VoidFromTime AND d.VoidToTime)) THEN 1
					ELSE 0 END 

	SELECT @SingleCount = SUM(SingleCount)
		  ,@MainParlayCount = SUM(MainParlayCount)
	FROM #tblGetLogInfo
	
	IF @SingleCount > 0
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID)
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
		FROM #TVSTicketBets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId AND rd.VoidFromTime = t.VoidFromTime AND rd.VoidToTime = t.VoidToTime
		WHERE rd.RequestId = @RequestId  AND t.IsMixParlay = 0
	END

	IF @MainParlayCount > 0
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId, SiteDBGroupID)
		SELECT @RequestId
			, @IssueTypeId
			, rd.SubIssueTypeId
			, t.Subtransid
			, t.MatchId
			, rd.Id AS RequestDetailId
			, t.TransId
			, t.SiteDBGroupID
		FROM #TVSTicketBets t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId AND rd.VoidFromTime = t.VoidFromTime AND rd.VoidToTime = t.VoidToTime
		WHERE rd.RequestId = @RequestId AND t.IsMixParlay = 1
	END

	-- Get content of log data 
	SET @LogDataContent = ''
	SELECT @actualscore = SUBSTRING(l.LiveScores, CHARINDEX(';Act:',l.LiveScores) + 5, LEN(l.LiveScores))
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
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	

	DROP TABLE #tblGetLogInfo
	DROP TABLE #tmpTransInfo
	DROP TABLE #TVSTicketBets
END
GO