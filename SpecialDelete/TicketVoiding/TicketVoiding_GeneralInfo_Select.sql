/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_GeneralInfo_Select]
( 
	 @RequestId	INT
	,@MatchId   INT = 0
)
AS
/*	Created by: 20201207@July
	Task: Optimize Voiding Workflow - General info delete bet check [Redmine:#145719]
	DB: DBCTG/bodb02

	Revisions: 
		- 20201207@July: Create new SP [Redmine:#145719]
		- 20201224@Zane: Return KO time [Redmine:#143666]
		- 20210305@July: TVS - Auto void before KO time - [Redmine: #150522] 
		- 20211202@Max: [TVS] Implement function allow to void bettrans14 [Redmine:#140180]
		- 20220820@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221207@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @VoidingHistoryId  INT
			,@xmlVoidData		XML = NULL
			,@xmlVoidResults	XML = NULL
			,@cnt_matchid		INT = 0
			,@NegativeBalanceUsers VARCHAR(MAX) = ''
			,@VoidingHistoryIds VARCHAR(MAX) = ''

	CREATE TABLE #tmpMatch 
	(
		 RequestId INT
		,Homeid INT
		,Awayid INT
		,Leagueid INT
		,RequestedBy INT
		,DecidedBy NVARCHAR(200)
		,KickOffTime DATETIME
		,ActionId TINYINT
	);
	
	CREATE TABLE #tmpVoidingHistory
	(
		RequestId INT
		,VoidingHistoryId INT
		,VoidData XML
		,VoidedBy INT
		,VoidResults XML
		,MatchId INT
		,NegativeBalanceUsers VARCHAR(MAX)
		,MessageId INT
		,IsFinish BIT
	)

	DECLARE @tmpContentMessage TABLE ( RequestId INT, VoidingHistoryId INT, ContentChineseSimplified NVARCHAR(4000), ContentEnglish NVARCHAR(4000))
	DECLARE @tmpVoidResults TABLE ( VoidingHistoryId INT, Message VARCHAR(MAX), Type INT)

	INSERT INTO #tmpMatch (RequestId, Homeid, Awayid, Leagueid, RequestedBy, DecidedBy, KickOffTime, ActionId)
	SELECT DISTINCT 
			 rd.RequestId
			,CASE WHEN r.IssuetypeId IN (13,17) THEN NULL ELSE m.homeid END
			,CASE WHEN r.IssuetypeId IN (13,17) THEN NULL ELSE m.awayid END
			,CASE WHEN r.IssuetypeId IN (13,17) THEN NULL ELSE m.leagueid END
			,r.UserId
			,r.DecidedBy
			,m.kickofftime
			,r.ActionId
	FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
		LEFT JOIN dbo.match m WITH(NOLOCK) ON rd.MatchId = m.matchid
	WHERE rd.RequestId = @RequestId AND (rd.MatchId = @MatchId OR @MatchId IN (0,29))
	
	INSERT INTO #tmpVoidingHistory(RequestId, VoidingHistoryId, VoidedBy, VoidData) 
	SELECT	 vh.RequestId
			,vh.VoidingHistoryId
			,vh.UserId AS VoidedBy
			,vh.VoidData
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
	WHERE vh.RequestId = @RequestId AND vh.StatusId IN (2,3) 
	
	SELECT @cnt_matchid = COUNT(matchid)
	FROM  Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
	WHERE RequestId = @RequestId

	IF @cnt_matchid = 1 --Many voidinghistory 1 request -> 1 match
	BEGIN
		UPDATE vh
		SET vh.VoidResults = s.VoidResults
		   ,vh.matchid = s.matchID
		   ,vh.NegativeBalanceUsers = s.NegativeBalanceUsers
		   ,vh.MessageId = s.MessageId
		FROM #tmpVoidingHistory vh
			INNER JOIN Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) ON vh.RequestId = s.RequestID 
		WHERE (s.MatchId = @MatchId OR @MatchId IN (0,29))
	END
	ELSE --Many voidinghistory 1 request -> matches
	begin
		UPDATE vh
		SET vh.VoidResults = s.VoidResults
			,vh.matchid = s.matchid
		    ,vh.NegativeBalanceUsers = s.NegativeBalanceUsers
		    ,vh.MessageId = s.MessageId
		FROM #tmpVoidingHistory vh
			INNER JOIN Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) ON vh.RequestId = s.RequestID AND vh.VoidingHistoryId = s.VoidingHistoryId
		WHERE (s.MatchId = @MatchId OR @MatchId IN (0,29))
		
		DELETE FROM #tmpVoidingHistory WHERE MatchId IS NULL
	END

	SET @NegativeBalanceUsers = STUFF((SELECT DISTINCT ',' + NegativeBalanceUsers
									FROM #tmpVoidingHistory 
									FOR XML PATH ('')
									),1,1,'')
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) t
		SET IsFinish = 1
			,@xmlVoidData = T.VoidData
			,@VoidingHistoryId = T.VoidingHistoryId
			,@xmlVoidResults = T.VoidResults
		FROM #tmpVoidingHistory t
		WHERE t.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		SET @VoidingHistoryIds += CASE WHEN @VoidingHistoryIds = '' THEN '' ELSE ',' END + CAST (@VoidingHistoryId AS VARCHAR(100))

		INSERT INTO @tmpContentMessage (RequestId,VoidingHistoryId, ContentChineseSimplified,ContentEnglish)
		SELECT  @RequestId
				, @VoidingHistoryId
				, T.C.value('@ContentChineseSimplified', 'NVARCHAR(4000)')
				, T.C.value('@ContentEnglish', 'NVARCHAR(4000)')
		FROM	@xmlVoidData.nodes('/VoidData') AS T(C)
		OPTION (OPTIMIZE FOR (@xmlVoidData = NULL ))

		INSERT INTO @tmpVoidResults ( VoidingHistoryId, Message, Type)
		SELECT  @VoidingHistoryId,
				T.C.value('@Message', 'VARCHAR(MAX)') AS Message
				,T.C.value('@Type', 'INT') AS Type
		FROM	@xmlVoidResults.nodes('/VoidResults/VoidResult') as [T](C)
		OPTION (OPTIMIZE FOR (@xmlVoidResults = NULL ))
	END

	SELECT DISTINCT
		@RequestId AS RequestId
		,Homeid
		,Awayid
		,leagueid 
		,KickOffTime
		,DecidedBy
		,RequestedBy
		,@NegativeBalanceUsers AS NegativeBalanceUsers
		,@VoidingHistoryIds AS VoidingHistoryIds
	FROM #tmpMatch 

	SELECT DISTINCT
		s.VoidedBy
		,CASE WHEN m.ActionId IN (1,4,6,7) THEN msg.Content_cs ELSE cm.ContentChineseSimplified END AS ContentChineseSimplified
		,CASE WHEN m.ActionId IN (1,4,6,7) THEN msg.Content_en ELSE  cm.ContentEnglish END AS ContentEnglish
	FROM #tmpVoidingHistory s
	INNER JOIN #tmpMatch m ON s.RequestId = m.RequestId
	LEFT JOIN DBMSG.bodb_Message.dbo.Msg msg WITH (NOLOCK) ON s.MessageId = msg.MessageId
	LEFT JOIN @tmpContentMessage cm ON cm.RequestId = s.RequestId --AND cm.VoidingHistoryId = s.VoidingHistoryId

	SELECT  Message
		  ,Type
	FROM @tmpVoidResults

	DROP TABLE #tmpMatch
	DROP TABLE #tmpVoidingHistory

END

GO