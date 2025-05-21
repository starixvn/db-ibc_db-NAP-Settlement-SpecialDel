/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestDetail_MEC_Update]
(
	@RequestId				        INT
	,@IssueTypeId			        TINYINT		 = NULL
	,@UserId				        INT
	,@IP					        VARCHAR(50)	 = NULL
	,@MatchEarlyCompletedInfo		VARCHAR(MAX) = NULL
	,@TransInfoJson			        VARCHAR(MAX) = NULL
	,@IsEditRequest			        INT          = 0
)
AS
/*	
	Created by: 20250514@Lani
	Task: [TVS] New Issue Type - Match Early Completed - Create New SP [Redmine: #226438]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20250514@Lani: [TVS] New Issue Type - Match Early Completed - Create New SP [Redmine: #226438]

	Param's explanation:
		
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	@MatchEarlyCompletedInfoXML	 XML = NULL	
		   ,@topBatch			         INT = 4500

	CREATE TABLE #tblGetLogInfo (
			 RequestID				INT
			,MatchID				INT
			,SingleCount			INT 
			,MainParlayCount		INT 
			,VoidFromTime			DATETIME 
			,VoidToTime				DATETIME
			,SubIssueTypeId			SMALLINT
			,AdvancedExtraInfo		VARCHAR(MAX)
			,IssueDetail			NVARCHAR(MAX)
			,BettypeCount			VARCHAR(MAX)
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
	FROM STRING_SPLIT(@TransInfoJson, ',') f
		CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_TransInfoJson) t
		CROSS APPLY (
			SELECT mid ,t ,s_t ,c ,btype ,bid ,isP ,sitedb
			FROM OPENJSON(t.Decompress_TransInfoJson) 
			WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT
			)
		) tbl
	WHERE f.value <> ''

	SET @MatchEarlyCompletedInfoXML = CONVERT(XML, @MatchEarlyCompletedInfo)
	INSERT INTO #tblGetLogInfo( 
			RequestID				
			,MatchID						
			,SingleCount			
			,MainParlayCount		
			,VoidFromTime			
			,VoidToTime
			,BettypeCount				
			,SubIssueTypeId
			,AdvancedExtraInfo
			,IssueDetail
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@SingleCount','INT') AS SingleCount
			,t.c.value('@MainParlayCount','INT') AS MainParlayCount
			,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
			,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
			,REPLACE(t.c.value('@BetTypeCount','VARCHAR(MAX)'), '&quot;','''') AS BetTypeCount
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,REPLACE(t.c.value('@AdvancedExtraInfo','VARCHAR(MAX)'), '&quot;','''') AS AdvancedExtraInfo
			,REPLACE(t.c.value('@AllBetTypesSelectionJson','NVARCHAR(MAX)'), '&quot;','''') AS IssueDetail
	FROM @MatchEarlyCompletedInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@MatchEarlyCompletedInfoXML = NULL))

	IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL
		
		UPDATE	r
		SET	SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, SubIssueTypeId = l.SubIssueTypeId
			, AdvancedExtraInfo = l.AdvancedExtraInfo
			, IssueDetail = l.IssueDetail
			, TransIds = l.BettypeCount
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
		, SingleCount
		, MainParlayCount
		, VoidFromTime
		, VoidToTime
		, SubIssueTypeId
		, AdvancedExtraInfo
		, Sporttype
		, IssueDetail
		, TransIds
		)
	SELECT @RequestId
		, l.MatchID
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.kickofftime
		, l.SingleCount
		, l.MainParlayCount
		, l.VoidFromTime
		, l.VoidToTime
		, l.SubIssueTypeId
		, l.AdvancedExtraInfo
		, m.sporttype
		, l.IssueDetail
		, l.BettypeCount
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
				, 0
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

	SET @LogDataContent = ''
	
	SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20))
							+ ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							+ ', SingleCount: ' + CAST(l.SingleCount AS VARCHAR(20))
							+ ', MainParlayCount: ' + CAST(l.MainParlayCount AS VARCHAR(20))
							+ ', VoidFromTime: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidToTime: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
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