/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestDetail_OU_Update]
(
	@RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@WrongOUInfo		    VARCHAR(MAX) = NULL
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
		- 20220808@July: Create new SP - Split code issuetype wrong OU & wrong 1st OU [Redmine: #175412]

	Param's explanation:
		+ @IssueTypeId : 6 - Wrong OU, 7 - Wrong 1st OU
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogActionId		 INT
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	@WrongOUInfoXML		  XML = NULL	
			,@SingleCount			INT
		    ,@MainParlayCount		INT

	CREATE TABLE #tblGetLogInfo (
			 RequestID				INT
			,MatchID				INT
			,FilterFromTransTime	DATETIME 
			,FilterToTransTime		DATETIME 
			,SingleCount			INT 
			,MainParlayCount		INT 
			,VoidFromTime			DATETIME 
			,VoidToTime				DATETIME
			,LiveScores				NVARCHAR(300)
			,SubIssueTypeId			SMALLINT
			,WrongOU				VARCHAR(200)
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
	SELECT t.c.value('@mid','INT') AS matchid
			,t.c.value('@t','BIGINT') AS transid
			,t.c.value('@s_t','BIGINT') AS Subtransid
			,t.c.value('@c','INT') AS custid
			,t.c.value('@btype','SMALLINT') AS bettype
			,t.c.value('@bid','BIGINT') AS betid
			,t.c.value('@isP','BIT') AS IsMixParlay
			,t.c.value('@sitedb','SMALLINT') AS SiteDBGroupID
	FROM @TransInfo.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@TransInfo = NULL))

	SET @WrongOUInfoXML = CONVERT(XML, @WrongOUInfo)
	INSERT INTO #tblGetLogInfo( 
			RequestID				
			,MatchID				
			,FilterFromTransTime	
			,FilterToTransTime			
			,SingleCount			
			,MainParlayCount		
			,VoidFromTime			
			,VoidToTime	
			,LiveScores				
			,SubIssueTypeId
			,WrongOU
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@SingleCount','INT') AS SingleCount
			,t.c.value('@MainParlayCount','INT') AS MainParlayCount
			,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
			,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
			,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' AS LiveScores
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,'<r WrongMarket="' + REPLACE(t.c.value('@WrongMarket','VARCHAR(50)') , '&', '&amp;') + '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
						+ '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' AS WrongOU
	FROM @WrongOUInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongOUInfoXML = NULL))

	IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL
		
		UPDATE	r
		SET	  FilterFromTransTime = l.FilterFromTransTime
			, FilterToTransTime = l.FilterToTransTime
			, SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, IssueDetail = l.LiveScores
			, SubIssueTypeId = l.SubIssueTypeId
			, TransIds = l.WrongOU
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
		, SingleCount
		, MainParlayCount
		, VoidFromTime
		, VoidToTime
		, IssueDetail
		, SubIssueTypeId
		, TransIds
		)
	SELECT @RequestId
		, l.MatchID
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.kickofftime
		, l.FilterFromTransTime
		, l.FilterToTransTime
		, l.SingleCount
		, l.MainParlayCount
		, l.VoidFromTime
		, l.VoidToTime
		, l.LiveScores
		, l.SubIssueTypeId
		, l.WrongOU
	FROM #tblGetLogInfo l
		INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
		LEFT JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = l.RequestID AND rd.MatchId = l.MatchID
	WHERE rd.RequestId IS NULL

	IF @IsEditRequest = 0 
	BEGIN
		SET @LogActionId = 90001
	END 
	IF @IsEditRequest = 1
	BEGIN		
		SET @LogActionId = 90003

		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single
		WHERE RequestId = @RequestId	
			
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay
		WHERE RequestId = @RequestId	
	END

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
		FROM #tmpTransInfo t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  
		WHERE rd.RequestId = @RequestId AND t.IsMixParlay = 0
	END

	IF @MainParlayCount > 0
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_SubParlay(RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId, MainTransId, SiteDBGroupID)
		SELECT @RequestId
			 , @IssueTypeId
			 , rd.SubIssueTypeId
			 , t.SubTransid
			 , t.matchid
			 , rd.Id
			 , t.transid AS MainTransId
			 , t.SiteDBGroupID
		FROM #tmpTransInfo t
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId
		WHERE rd.RequestId = @RequestId AND t.IsMixParlay = 1
	END

	-- Get content of log data 
	SET @LogDataContent = ''
	
	SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20))
							+ ', FilterFromTransTime: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) +  ', FilterToTransTime: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
							+ ', VoidFromTime: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidToTime: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							+ CASE WHEN @IssueTypeId = 6 THEN ', WrongOU: ' + l.WrongOU
								   WHEN @IssueTypeId = 7 THEN ', Wrong 1st OU: ' + l.WrongOU ELSE '' END
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