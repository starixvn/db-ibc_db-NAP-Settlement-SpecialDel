/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_HDP_Update]
(
	 @RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@WrongHDPInfo			VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT = 0 
)
AS
/*	
	Created by: 20220808@July
	Task: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20220808@July: Create new SP - Split code issuetype wrong HDP & wrong 1st HDP [Redmine: #175412]
		- 20221124@July: [TVS] Increase data size when sending data between web and DB [Redmine: #180863]
		- 20221125@July: TVS - Wrong HDP affects to PH bet types [Redmine: #172486]
		- 20230103@Max: Change JSON input [Redmine: #180625]
		- 20230403@July: Remove check count single/parlay [Redmine: #172975]
		- 20230802@July: Remove code get list bettype Poolhouse [Redmine: #190441]

	Param's explanation:
		+ @IssueTypeId : 4 - Wrong HDP, 5 - Wrong 1st HDP
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @WrongHDPInfoXML	 XML = NULL	

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

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
			,WrongHDP				VARCHAR(MAX)
			)

	CREATE TABLE #tmpTransInfo(
		   matchid INT
		  ,transid BIGINT
		  ,Subtransid BIGINT
		  ,custid	INT	
		  ,bettype SMALLINT
		  ,Subbettype SMALLINT
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
		  ,Subbettype
		  ,betid
		  ,IsMixParlay
		  ,SiteDBGroupID
		)
	SELECT mid ,t ,s_t ,c ,btype ,s_btype ,bid ,isP ,sitedb
	FROM OPENJSON(@Decompress_TransInfoJson) 
	WITH( mid INT, t BIGINT ,s_t BIGINT ,c INT ,btype SMALLINT ,s_btype SMALLINT ,bid BIGINT ,isP BIT ,sitedb SMALLINT
	) tbl

	SET @WrongHDPInfoXML = CONVERT(XML, @WrongHDPInfo)
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
			,WrongHDP
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,CASE WHEN t.c.value('@FilterFromTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterFromTransTime','DATETIME') END AS FilterFromTransTime
			,CASE WHEN t.c.value('@FilterToTransTime','DATETIME') = '1900-01-01 00:00:00.000' THEN NULL ELSE t.c.value('@FilterToTransTime','DATETIME') END AS FilterToTransTime
			,t.c.value('@LiveGameEarlySingleCount','INT') + t.c.value('@PoolHouseSingleCount','INT') AS SingleCount
			,t.c.value('@PoolHouseMainParlayCount','INT') AS MainParlayCount
			,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
			,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
			,'Live:' + t.c.value('@LiveScores','VARCHAR(50)') + ';Act:' 
					 + ';LiveGameEarlySingleCount:' + CAST(t.c.value('@LiveGameEarlySingleCount','INT') AS VARCHAR(50))
					 + ';PoolHouseSingleCount:' + CAST(t.c.value('@PoolHouseSingleCount','INT') AS VARCHAR(50))
					 + ';PoolHouseMainParlayCount:' + CAST(t.c.value('@PoolHouseMainParlayCount','INT') AS VARCHAR(50)) AS LiveScores
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,CASE WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (8,9) AND ISNULL(t.c.value('@HomeFavorite','VARCHAR(50)'),'') <> '' 
					THEN '<r HomeFavorite="' + REPLACE(t.c.value('@HomeFavorite','VARCHAR(50)') , '&', '&amp;') + '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
				  WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (8,9) AND ISNULL(t.c.value('@AwayFavorite','VARCHAR(50)'),'') <> '' 
					THEN '<r AwayFavorite="' + REPLACE(t.c.value('@AwayFavorite','VARCHAR(50)') , '&', '&amp;') + '" ActualMarket="'+ REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(t.c.value('@ActualMarket','VARCHAR(50)'),'&','&amp;'),'"','&quot;') ,'''','&apos;'),'<','&lt;'),'>','&gt;') --Replace special character -> web parse show edit
				  WHEN t.c.value('@SubIssueTypeId','SMALLINT') IN (22,23,24,25) AND ISNULL(t.c.value('@HdpValue','VARCHAR(50)'),'') <> '' 
					THEN '<r HdpValue="' + REPLACE(t.c.value('@HdpValue','VARCHAR(50)') , '&', '&amp;') 
				  ELSE '' END 
				    + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') 
				    + CASE WHEN t.c.value('@IsMainMatch','VARCHAR(10)') = 'False' 
						THEN '" LiveIndicator="' + CAST(t.c.value('@LiveIndicator','BIT') AS VARCHAR(10)) 
						     + '" />'
					  ELSE 
							 '" LiveIndicator="' + CAST(t.c.value('@LiveIndicator','BIT') AS VARCHAR(10))
							+ '" IsLinkGroup1X2="' + CAST(t.c.value('@IsLinkGroup1X2','BIT') AS VARCHAR(10))
							+ '" IsLinkGroupAIO="' + CAST(t.c.value('@IsLinkGroupAIO','BIT') AS VARCHAR(10))
							+ '" PoolHouseCheckedBetTypes="' + t.c.value('@PoolHouseCheckedBetTypes','VARCHAR(MAX)') 
							+ '" />'
					 END
			AS WrongHDP
	FROM @WrongHDPInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@WrongHDPInfoXML = NULL))

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
			, TransIds = l.WrongHDP
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
		, l.WrongHDP
	FROM #tblGetLogInfo l
		INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
		LEFT JOIN dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) ON rd.RequestId = l.RequestID AND rd.MatchId = l.MatchID
	WHERE rd.RequestId IS NULL

	IF @IsEditRequest = 1
	BEGIN		
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_Single
		WHERE RequestId = @RequestId	
			
		DELETE FROM dbo.TicketVoiding_RequestDetailTicket_SubParlay
		WHERE RequestId = @RequestId	
	END

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

	SET @LogDataContent = ''
	SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20))
							+ ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							+ ', FilterFromTransTime: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) +  ', FilterToTransTime: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
							+ ', VoidFromTime: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidToTime: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							+ CASE WHEN @IssueTypeId = 4 THEN ', WrongHDP: ' + l.WrongHDP
								   WHEN @IssueTypeId = 5 THEN ', Wrong 1st HDP: ' + l.WrongHDP ELSE '' END
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