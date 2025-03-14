/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_RO_Update]
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
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20230912@Max: [TVS] - Update the rules to get void ticket for Reduced Over issue type [Redmine: #193824]
		- 20231207@Max: [TVS] Not Participate - Support user select exact bet type [Redmine: #197018]
		- 20240411@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240701@July: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
		- 20250311@July: [TVS] Enhance the Out-of-Memory [Redmine: #217771]

	Param's explanation:
		+ @IssueTypeId : 19 - Reduced Over
		+ @IssueTypeId : 21 - Not Participate
		+ @IssueTypeId : 23 - Abandoned
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME = GETDATE()
			,@EndTime			 DATETIME
			,@LogData			 NVARCHAR(MAX)
			,@SB_Error			 BIT = 0
			,@LogDataContent	 NVARCHAR(MAX)

	DECLARE	 @ReducedOverInfoXML	 XML = NULL	

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

	SET @ReducedOverInfoXML = CONVERT(XML, @ReducedOverInfo)
	INSERT INTO #tblGetLogInfo( 
			RequestID				
			,MatchID				
			,SingleCount			
			,MainParlayCount		
			,VoidFromTime			
			,VoidToTime	
			,LiveScores		
			,SubIssueTypeId
			,ReducedOver
		)
	SELECT @RequestId AS RequestId
			,t.c.value('@MatchId','INT') AS MatchID
			,t.c.value('@SingleCount','INT') AS SingleCount
			,t.c.value('@MainParlayCount','INT') AS MainParlayCount
			,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
			,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
			,NULL AS LiveScores
			,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			,CASE WHEN @IssueTypeId IN (19, 23) THEN '<r BetTypeIds="' + t.c.value('@BetTypeIds','VARCHAR(MAX)')
				+ '" WicketOver="' + t.c.value('@WicketOver','VARCHAR(20)')
				+ '" PlayerIds="' + t.c.value('@PlayerIds','VARCHAR(MAX)')
				+ '" Runs="' + t.c.value('@Runs','VARCHAR(20)')
				+ '" Live="' + CAST(t.c.value('@Live','BIT') AS VARCHAR(10)) 
				+ '" NonLive="' + CAST(t.c.value('@NonLive','BIT') AS VARCHAR(10)) 	
				+ '" />'
				WHEN @IssueTypeId = 21 THEN '<r PlayerId="' + t.c.value('@PlayerId','VARCHAR(MAX)')
				+ '" BetTypeIds="' + t.c.value('@BetTypeIds','VARCHAR(MAX)')
				+ '" />'
				END
				AS  ReducedOver
	FROM @ReducedOverInfoXML.nodes('root/r') t(c)
	OPTION (OPTIMIZE FOR (@ReducedOverInfoXML = NULL))
	
	IF @IsEditRequest = 1
	BEGIN
		DELETE rd
		FROM dbo.TicketVoiding_RequestDetail rd
		WHERE rd.RequestId = @RequestId
	END

	INSERT INTO dbo.TicketVoiding_RequestDetail (
		RequestId
		, MatchId
		, LeagueId
		, HomeId
		, AwayId
		, Sporttype
		, SingleCount
		, MainParlayCount
		, VoidFromTime
		, VoidToTime
		, IssueDetail
		, SubIssueTypeId
		, TransIds
		, RequestType
		)
	SELECT @RequestId
		, l.MatchID
		, m.leagueid
		, m.homeid
		, m.awayid
		, m.sporttype
		, l.SingleCount
		, l.MainParlayCount
		, l.VoidFromTime
		, l.VoidToTime
		, l.LiveScores
		, l.SubIssueTypeId
		, l.ReducedOver
		, CASE WHEN @ActionId = 9 THEN 1 ELSE 0 END
	FROM #tblGetLogInfo l
		INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID

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
		CROSS APPLY (
			SELECT TOP 1 rd.Id, rd.SubIssueTypeId
			FROM  dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
			WHERE rd.RequestId = @RequestId
				AND t.matchid = rd.MatchId
		)rd
	WHERE t.IsMixParlay = 0

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
		CROSS APPLY (
			SELECT TOP 1 rd.Id, rd.SubIssueTypeId
			FROM  dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
			WHERE rd.RequestId = @RequestId
				AND t.matchid = rd.MatchId
		)rd
	WHERE t.IsMixParlay = 1

	SET @LogDataContent = ''
	SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20))
							+ ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							+ ', VoidFromTime: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							+ ', VoidToTime: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							+ CASE WHEN @IssueTypeId = 19 THEN ', ReducedOver: '
								   WHEN @IssueTypeId = 21 THEN ', NotParticipate: '
								   WHEN @IssueTypeId = 23 THEN ', Abandoned: '
								+ l.ReducedOver
							END
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