/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[TicketVoiding_GeneralInfo_Select]
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
	
	-- single
	INSERT INTO #tmpVoidingHistory(RequestId, VoidingHistoryId, VoidedBy, VoidedTime) 
	SELECT	 vh.RequestId
			,vh.VoidingHistoryId
			,vh.UserId AS VoidedBy
			,vh.CreatedDate
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		CROSS APPLY 
			(
				SELECT TOP 1 z.VoidingHistoryId
				FROM  dbo.zzzbettrans z WITH(NOLOCK) 
				WHERE z.VoidingHistoryId = vh.VoidingHistoryId
					AND (z.matchid = @MatchId OR @MatchId = 0)
					AND 1 = CASE
								WHEN z.bettype = 911 THEN 1
								WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
								ELSE 0
							END
			)z
	WHERE vh.RequestId = @RequestId AND vh.StatusId IN (2,3) 
		
	UNION 
	-- parlay
	SELECT   vh.RequestId
			,vh.VoidingHistoryId
			,vh.UserId AS VoidedBy
			,vh.CreatedDate
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
		CROSS APPLY 
			( 
				SELECT TOP 1 zm.VoidingHistoryId
				FROM dbo.zzzbettransm zm WITH(NOLOCK) 
				WHERE zm.VoidingHistoryId = vh.VoidingHistoryId
				AND (zm.matchid = @MatchId OR @MatchId = 0)
			)zm	
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
		,CASE WHEN m.ActionId IN (1,4) THEN sv.Content_cs ELSE cm.ContentChineseSimplified END AS ContentChineseSimplified
		,CASE WHEN m.ActionId IN (1,4) THEN sv.Content_en ELSE  cm.ContentEnglish END AS ContentEnglish
		,sv.NegativeBalanceUsers
	FROM #tmpVoidingHistory s
	INNER JOIN #tmpMatch m ON s.RequestId = m.RequestId
	OUTER APPLY( SELECT sv.NegativeBalanceUsers, m.Content_en, m.Content_cs
				 FROM dbo.Ticketvoiding_VoidBetAutomation_Service sv WITH (NOLOCK) 
					INNER JOIN DBMSG.bodb_Message.dbo.Msg m WITH (NOLOCK) ON sv.MessageId = m.MessageId
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