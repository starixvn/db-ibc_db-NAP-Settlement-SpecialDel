/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_RequestDetail_RO_Update]
(
	 @RequestId				INT
	,@IssueTypeId			TINYINT		= NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@ReducedOverInfo		VARCHAR(MAX) = NULL
	,@TransInfoJson			VARCHAR(MAX) = NULL
	,@IsEditRequest			INT = 0 
)
AS
/*	
	Created by: 20230612@July
	Task: [TVS] Support void Cricket when reducing over [Redmine: #185833]
	DB: DBCTG/bodb02
	
	Revisions: 
		- 20230612@July: Create new SP [Redmine: #185833]

	Param's explanation:
		+ @IssueTypeId : 19 - Reduced Over
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @ReducedOverInfoXML	 XML = NULL	

	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX) = NULL

	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), @TransInfoJson, 1)) AS NVARCHAR(MAX))

	CREATE TABLE #tblGetLogInfo (
			 RequestID				INT
			,MatchID				INT
			,SingleCount			INT 
			,MainParlayCount		INT 
			,VoidFromTime			DATETIME 
			,VoidToTime				DATETIME
			,LiveScores				NVARCHAR(300)
			,SubIssueTypeId			SMALLINT
			,ReducedOver			VARCHAR(MAX)
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

	SET @ReducedOverInfoXML = CONVERT(XML, @ReducedOverInfo)
	INSERT INTO #tblGetLogInfo( 
			RequestID				
			,MatchID				
			,SingleCount			
			,MainParlayCount		
			,VoidFromTime			
			,VoidToTime			
			,SubIssueTypeId
			,ReducedOver
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@SingleCount','INT') AS SingleCount
			,t.c.value('@MainParlayCount','INT') AS MainParlayCount
			,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
			,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,'<r BetTypeIds="' + t.c.value('@BetTypeIds','VARCHAR(MAX)')
				+ '" WicketOver="' + t.c.value('@WicketOver','VARCHAR(20)')
				+ '" PlayerIds="' + t.c.value('@PlayerIds','VARCHAR(20)')
				+ '" Runs="' + t.c.value('@Runs','VARCHAR(20)')
				+ '" Live="' + CAST(t.c.value('@Live','BIT') AS VARCHAR(10)) 
				+ '" NonLive="' + CAST(t.c.value('@NonLive','BIT') AS VARCHAR(10)) 	
				+ '" />'
				AS  ReducedOver
	FROM @ReducedOverInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@ReducedOverInfoXML = NULL))
	
	IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
			LEFT JOIN #tblGetLogInfo t ON rd.RequestId = t.RequestID AND rd.MatchId = t.MatchID
		WHERE rd.RequestId = @RequestId AND t.RequestID IS NULL
		
		UPDATE	r
		SET	  SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, SubIssueTypeId = l.SubIssueTypeId
			, TransIds = l.ReducedOver
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
		, TransIds
		, RequestType
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
		, l.ReducedOver
		, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
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
							+ ', VoidFromTime: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidToTime: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							+ ', ReducedOver: ' + l.ReducedOver
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