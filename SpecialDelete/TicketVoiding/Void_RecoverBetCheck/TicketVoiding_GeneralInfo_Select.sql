/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
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
		- 20230814@Max: [TVS] Reduced Over - Update rule for action "auto void" [Redmine: #191762]
		- 20231102@Max: [TVS] Abnormal Account - Void tickets based on the differences between the losing amount and the given credit of the member [Redmine: #194140]
		- 20231211@July: [TVS] Remove SABA text of league name in case void many matches and apply new way to remove SABA text [Redmine: #196627]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240308@Max: [TVS] Abnormal Bet - Support void archived tickets [Redmine: #196019]

	Param's explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE  @VoidingHistoryId  INT
			,@xmlVoidResults	XML = NULL
			,@cnt_matchid		INT = 0
			,@NegativeBalanceUsers VARCHAR(MAX) = ''
			,@VoidingHistoryIds VARCHAR(MAX) = ''
			,@SingleTransIds	VARCHAR(MAX) = ''

	CREATE TABLE #tmpMatch 
	(
		 RequestId INT
		,Homeid INT
		,Awayid INT
		,Leagueid INT
		,RequestedBy INT
		,DecidedBy NVARCHAR(200)
		,KickOffTime DATETIME
		,IssuetypeId TINYINT 
		,RecoveredTime DATETIME
	);
	
	CREATE TABLE #tmpVoidingHistory
	(
		RequestId INT
		,VoidingHistoryId INT
		,VoidedBy INT
		,VoidResults XML
		,MatchId INT
		,NegativeBalanceUsers VARCHAR(MAX)
		,MessageId INT
		,IsFinish BIT
	)

	DECLARE @tmpVoidResults TABLE ( VoidingHistoryId INT, Message VARCHAR(MAX), Type INT)

	INSERT INTO #tmpMatch (RequestId, Homeid, Awayid, Leagueid, RequestedBy, DecidedBy, KickOffTime, IssuetypeId, RecoveredTime)
	SELECT DISTINCT 
			 rd.RequestId
			,CASE WHEN r.IssuetypeId IN (13,17,22) THEN NULL ELSE m.homeid END
			,CASE WHEN r.IssuetypeId IN (13,17,22) THEN NULL ELSE m.awayid END
			,CASE WHEN r.IssuetypeId IN (13,17,22) THEN NULL ELSE m.leagueid END
			,r.UserId
			,r.DecidedBy
			,CASE WHEN r.IssuetypeId IN (13,17,22) THEN NULL ELSE m.kickofftime END 
			,r.IssueTypeId
			,CASE WHEN r.IssuetypeId IN (22) THEN r.CreatedDate ELSE NULL END AS RecoveredTime
	FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
		OUTER APPLY (
					SELECT m.matchid, m.homeid, m.awayid, m.leagueid, m.kickofftime
					FROM	dbo.match m WITH(NOLOCK)
					WHERE rd.MatchId = m.matchid
					UNION
					SELECT	m14.MatchId, m14.homeid, m14.awayid, m14.leagueid, m14.kickofftime
					FROM	dbo.match14 m14 WITH(NOLOCK)
					WHERE rd.MatchId = m14.matchid
					) m
	WHERE rd.RequestId = @RequestId AND (rd.MatchId = @MatchId OR @MatchId IN (0,29))
	
	IF EXISTS ( SELECT TOP 1 1 FROM #tmpMatch WHERE IssuetypeId = 22) --Recover Ticket
	BEGIN
		SET @SingleTransIds = STUFF((SELECT  ',' + CAST (TransId AS VARCHAR(50))
									FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH(NOLOCK)
									WHERE RequestId = @RequestId
									FOR XML PATH ('')),1,1,'')
	END

    INSERT INTO #tmpVoidingHistory(RequestId, VoidingHistoryId, VoidedBy) 
	SELECT	 vh.RequestId
			,vh.VoidingHistoryId
			,vh.UserId AS VoidedBy
	FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
	WHERE vh.RequestId = @RequestId AND vh.StatusId IN (2,3) 
	
	SET @VoidingHistoryIds = STUFF((SELECT  ',' + CAST (VoidingHistoryId AS VARCHAR(50))
									FROM #tmpVoidingHistory
									FOR XML PATH ('')),1,1,'')

	SELECT @cnt_matchid = COUNT(matchid)
	FROM  Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
	WHERE RequestId = @RequestId

	IF @cnt_matchid = 1 --Many voidinghistory 1 request -> 1 match
	BEGIN
		UPDATE vh
		SET vh.VoidResults = s.VoidResults
		   ,vh.matchid = s.matchID
		   ,vh.NegativeBalanceUsers = s.NegativeBalanceUsers
		   ,vh.MessageId = ISNULL(s.MessageId,s.MessageIdSpecial)
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
		    ,vh.MessageId = ISNULL(s.MessageId,s.MessageIdSpecial)
		FROM #tmpVoidingHistory vh
			INNER JOIN Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) ON vh.RequestId = s.RequestID AND vh.VoidingHistoryId = s.VoidingHistoryId
		WHERE (s.MatchId = @MatchId OR @MatchId IN (0,29))
		
		DELETE FROM #tmpVoidingHistory WHERE MatchId IS NULL
	END
	
	SET @NegativeBalanceUsers = STUFF((SELECT DISTINCT ',' + a.NegativeBalanceUser
									FROM #tmpVoidingHistory t
										CROSS APPLY (
											SELECT value AS NegativeBalanceUser FROM STRING_SPLIT(t.NegativeBalanceUsers, ',') 
										)a
									WHERE ISNULL(t.NegativeBalanceUsers,'') <> ''
									FOR XML PATH ('')
									),1,1,'')
	
	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) t
		SET IsFinish = 1
			,@VoidingHistoryId = t.VoidingHistoryId
			,@xmlVoidResults = t.VoidResults
		FROM #tmpVoidingHistory t
		WHERE t.IsFinish IS NULL

		IF @@ROWCOUNT = 0 BREAK

		INSERT INTO @tmpVoidResults ( VoidingHistoryId, Message, Type)
		SELECT  @VoidingHistoryId,
				T.C.value('@Message', 'VARCHAR(MAX)') AS Message
				,T.C.value('@Type', 'INT') AS Type
		FROM	@xmlVoidResults.nodes('/VoidResults/VoidResult') as [T](C)
		OPTION (OPTIMIZE FOR (@xmlVoidResults = NULL ))
	END

	SELECT DISTINCT
		@RequestId AS RequestId
		,t.Homeid
		,t.Awayid
		,t.Leagueid 
		,t.KickOffTime
		,t.DecidedBy
		,v.Username AS RequestedBy
		,@NegativeBalanceUsers AS NegativeBalanceUsers
		,@VoidingHistoryIds AS VoidingHistoryIds
		,@SingleTransIds AS SingleTransIds
		,t.RecoveredTime
	FROM #tmpMatch t
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.RequestedBy = v.CustId

	SELECT DISTINCT
		v.Username AS VoidedBy
		,msg.Content_cs AS ContentChineseSimplified
		,msg.Content_en AS ContentEnglish
	FROM #tmpVoidingHistory s
	INNER JOIN #tmpMatch m ON s.RequestId = m.RequestId
	INNER JOIN CustDB.dbo.Customer v WITH(NOLOCK) ON s.VoidedBy = v.CustId
	LEFT JOIN DBMSG.bodb_Message.dbo.Msg msg WITH (NOLOCK) ON s.MessageId = msg.MessageId
	WHERE 1 = CASE WHEN m.IssuetypeId <> 17 THEN 1 ELSE 0 END

	SELECT DISTINCT Message
		  ,Type
	FROM @tmpVoidResults

	DROP TABLE #tmpMatch
	DROP TABLE #tmpVoidingHistory

END

GO

