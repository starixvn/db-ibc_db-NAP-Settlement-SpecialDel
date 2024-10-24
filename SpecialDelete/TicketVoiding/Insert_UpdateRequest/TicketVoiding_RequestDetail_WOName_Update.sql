/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_WOName_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT	= 26
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@WrongOfferedNameInfo  NVARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT 
)
AS
/*	
	Created by: 20240925@July
	Task: [TVS] New Issue Type "Wrong Offered Name" [Redmine: #187408]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20240925@July: Create new SP [Redmine:#197051]

	Param's explanation:	
		- @WrongOfferedNameInfo: <root><r MatchId="" @CurrencyIds="" LicenseeNames="" /></root>
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @WrongOfferedNameInfoXML	XML = NULL
			,@topBatch			  INT = 4500

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #tblGetLogInfo (
			 RequestID				INT
			,MatchID				INT
			,SubIssueTypeId			SMALLINT
			,WrongOfferedName		NVARCHAR(MAX) 
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
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT
	) tbl

	SET @WrongOfferedNameInfoXML = CONVERT(XML, @WrongOfferedNameInfo)
	INSERT INTO #tblGetLogInfo( 
			RequestID				
			,MatchID				
			,SubIssueTypeId
			,WrongOfferedName
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,'<r CurrencyIds="' + t.c.value('@CurrencyIds','VARCHAR(MAX)')
				+ '" LicenseeNames="' + t.c.value('@LicenseeNames','VARCHAR(MAX)')
				+ CASE WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (126,128) THEN 
						'" WrongName="' + t.c.value('@WrongName','NVARCHAR(MAX)')
						+ '" ActualName="' + t.c.value('@ActualName','NVARCHAR(MAX)')
					   WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (127,129) THEN
						'" WrongNameT="' + t.c.value('@WrongNameT','NVARCHAR(MAX)')
						+ '" ActualNameT="' + t.c.value('@ActualNameT','NVARCHAR(MAX)')
					    + '" WrongNameS="' + t.c.value('@WrongNameS','NVARCHAR(MAX)')
						+ '" ActualNameS="' + t.c.value('@ActualNameS','NVARCHAR(MAX)')
						ELSE '' END
			+ '" />' AS WrongOfferedName
	FROM @WrongOfferedNameInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongOfferedNameInfoXML = NULL))

	IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL
		
		UPDATE	r
		SET	 TransIds = l.WrongOfferedName
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
		, Sporttype
		, TransIds
		, SubIssueTypeId
		, RequestType
		)
	SELECT @RequestId
		, l.MatchID
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.Sporttype
		, l.WrongOfferedName
		, l.SubIssueTypeId
		, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
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
							+ ', WrongOfferedName: ' + l.WrongOfferedName
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