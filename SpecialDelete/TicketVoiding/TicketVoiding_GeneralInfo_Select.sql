/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_GeneralInfo_Select]
( 
	 @RequestId	INT
	,@MatchId   INT = 0
)
AS
	/*	Created by: 20201207@July
	Task: Optimize Voiding Workflow - General info delete bet check [Redmine:#145719]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20201207@July: Create new SP [Redmine:#145719]
		- 20201224@Zane: Return KO time [Redmine:#143666]
		- 20210305@July: TVS - Auto void before KO time - [Redmine: #150522] 
		- 20211202@Max: [TVS] Implement function allow to void bettrans14 [Redmine:#140180]
		- 20220820@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @VoidingHistoryId  INT
			,@xmlVoidData		XML = NULL
			,@xmlVoidResults	XML = NULL

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
		,VoidedTime DATETIME
		,IsFinish BIT
	)

	DECLARE @tmpContentMessage TABLE ( RequestId INT, VoidingHistoryId INT, ContentChineseSimplified NVARCHAR(4000), ContentEnglish NVARCHAR(4000))
	DECLARE @tmpVoidResults TABLE ( VoidingHistoryId INT, Message VARCHAR(MAX), Type INT)

	INSERT INTO #tmpMatch (RequestId, Homeid, Awayid, Leagueid, RequestedBy, DecidedBy, KickOffTime, ActionId)
	SELECT DISTINCT 
			 rd.RequestId
			,CASE WHEN r.IssuetypeId = 13 THEN NULL ELSE m.homeid END
			,CASE WHEN r.IssuetypeId = 13 THEN NULL ELSE m.awayid END
			,CASE WHEN r.IssuetypeId = 13 THEN NULL ELSE m.leagueid END
			,r.UserId
			,r.DecidedBy
			,rd.kickofftime
			,r.ActionId
	FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
		LEFT JOIN dbo.match m WITH(NOLOCK) ON rd.MatchId = m.matchid
	WHERE rd.RequestId = @RequestId AND (rd.MatchId = @MatchId OR @MatchId = 0)
	
	INSERT INTO #tmpVoidingHistory(RequestId, VoidingHistoryId, VoidedBy, VoidedTime) 
	SELECT	 vh.RequestId
			,vh.VoidingHistoryId
			,vh.UserId AS VoidedBy
			,vh.CreatedDate
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
	WHERE vh.RequestId = @RequestId AND vh.StatusId IN (2,3) 

	--Update column XML
	UPDATE h
	SET  h.VoidData = vh.VoidData
	    ,h.VoidResults = s.VoidResults
	FROM #tmpVoidingHistory h
		INNER JOIN dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) ON h.VoidingHistoryId = vh.VoidingHistoryId
		LEFT JOIN Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) ON h.RequestId = s.RequestID AND h.VoidingHistoryId = s.VoidingHistory

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

		INSERT INTO @tmpContentMessage (RequestId,VoidingHistoryId, ContentChineseSimplified,ContentEnglish)
		SELECT  @RequestId
				, @VoidingHistoryId
				, T.C.value('@ContentChineseSimplified', 'NVARCHAR(4000)')
				, T.C.value('@ContentEnglish', 'NVARCHAR(4000)')
		FROM	@xmlVoidData.nodes('/VoidData') AS T(C)
		OPTION (OPTIMIZE FOR (@xmlVoidData = NULL ))

		INSERT INTO @tmpVoidResults (VoidingHistoryId, Message, Type)
		SELECT  @VoidingHistoryId
				,T.C.value('@Message', 'VARCHAR(MAX)') AS Message
				,T.C.value('@Type', 'INT') AS Type
		FROM	@xmlVoidResults.nodes('/VoidResults/VoidResult') as [T](C)
		OPTION (OPTIMIZE FOR (@xmlVoidResults = NULL ))
	END

	SELECT DISTINCT
		 s.VoidingHistoryId
		,s.VoidedTime
		,m.Homeid
		,m.Awayid
		,m.leagueid 
		,m.KickOffTime
		,m.DecidedBy
		,m.RequestedBy
		,s.VoidedBy
		,CASE WHEN m.ActionId IN (1,4,6,7) THEN sv.Content_cs ELSE cm.ContentChineseSimplified END AS ContentChineseSimplified
		,CASE WHEN m.ActionId IN (1,4,6,7) THEN sv.Content_en ELSE  cm.ContentEnglish END AS ContentEnglish
		,sv.NegativeBalanceUsers
	FROM #tmpVoidingHistory s
	INNER JOIN #tmpMatch m ON s.RequestId = m.RequestId
	OUTER APPLY( 
				SELECT sv.NegativeBalanceUsers, msg.Content_en, msg.Content_cs
				FROM dbo.Ticketvoiding_VoidBetAutomation_Service sv WITH (NOLOCK) 
				OUTER APPLY (
						SELECT  msg.Content_en, msg.Content_cs
						FROM DBMSG.bodb_Message.dbo.Msg msg WITH (NOLOCK) 
						WHERE sv.MessageId = msg.MessageId
					)msg
				WHERE s.RequestId = sv.RequestID AND s.VoidingHistoryId = sv.VoidingHistory
					AND sv.RequestID = @RequestId
			)sv
	LEFT JOIN @tmpContentMessage cm ON cm.RequestId = s.RequestId AND cm.VoidingHistoryId = s.VoidingHistoryId

	SELECT VoidingHistoryId
		  ,Message
		  ,Type
	FROM @tmpVoidResults

	DROP TABLE #tmpMatch
	DROP TABLE #tmpVoidingHistory

END

GO