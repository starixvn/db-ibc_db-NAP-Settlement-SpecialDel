/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_TE_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT	= 12
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@TechnicalErrorInfo    VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT 
)
AS
/*	
	Created by: 20240522@Max
	Task: [TVS] Wrong Market Offered issue type [Redmine: #197051]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220727@Max: Create new SP [Redmine:#197051]
		- 20240701@July: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
		- 20241025@July: [TVS] Add new Advanced Mode for TVS - [Redmine: #212394]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

	Param's explanation:	
		- @AdvancedModeInfo: <root><r MatchId="" FilterFromTransTime="" FilterToTransTime ="" FilterBy=""/></root>
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @TechnicalErrorXML		  XML = NULL
			,@topBatch			  INT = 4500

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
			,BetTypeCount			VARCHAR(MAX)
			,AdvancedExtraInfo		VARCHAR(MAX)
			,SubIssueTypeId			SMALLINT
			,IssueDetail			NVARCHAR(MAX)
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
	SELECT m_mid ,t ,s_t ,c ,btype ,bid ,isP ,sitedb ,isCCO
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
			SELECT m_mid ,t ,s_t ,c ,btype ,bid ,isP ,sitedb ,isCCO
			FROM OPENJSON(t.Decompress_TransInfoJson) 
			WITH( m_mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT, isCCO BIT
			)
		) tbl
	WHERE f.value <> ''

	SET @TechnicalErrorXML = CONVERT(XML, @TechnicalErrorInfo)
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
			,BetTypeCount			
			,AdvancedExtraInfo
			,SubIssueTypeId
			,IssueDetail
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
			,REPLACE(t.c.value('@BetTypeCount','VARCHAR(MAX)'), '&quot;','''') AS BetTypeCount
			,REPLACE(t.c.value('@AdvancedExtraInfo','VARCHAR(MAX)'), '&quot;','''') AS AdvancedExtraInfo
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,REPLACE(t.c.value('@AllBetTypesSelectionJson','NVARCHAR(MAX)'), '&quot;','''') AS IssueDetail
	FROM @TechnicalErrorXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TechnicalErrorXML = NULL))

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
			, SubIssueTypeId = l.SubIssueTypeId
			, AdvancedExtraInfo = l.AdvancedExtraInfo
			, TransIds = l.BetTypeCount
			, IssueDetail = l.IssueDetail
		FROM dbo.TicketVoiding_RequestDetail r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblGetLogInfo l ON l.RequestID = r.RequestId AND l.MatchID = r.MatchId
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
		, TransIds
		, SubIssueTypeId
		, AdvancedExtraInfo
		, IssueDetail
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
		, l.BetTypeCount
		, l.SubIssueTypeId
		, l.AdvancedExtraInfo
		, l.IssueDetail
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
				, DELETED.IsCancelCashOut
		INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, bettype, betid, CustId, SiteDBGroupID, IsCancelCO)
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
							+ ', FilterFrom: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) 
							+ ', FilterTo: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
							+ ', SingleCount: ' + CAST(l.SingleCount AS VARCHAR(20))
							+ ', MainParlayCount: ' + CAST(l.MainParlayCount AS VARCHAR(20))
							+ ', VoidFrom: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidTo: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
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
	) AS NVARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #tblGetLogInfo
	DROP TABLE #tmpTransInfo
	
END
GO