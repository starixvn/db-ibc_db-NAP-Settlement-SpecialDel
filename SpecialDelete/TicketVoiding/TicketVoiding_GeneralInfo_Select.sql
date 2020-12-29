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

	DECLARE @IsMovebet			BIT = 0
			,@VoidingHistoryId  INT
			,@xmlVoidData		XML = NULL
			,@xmlVoidResults	XML = NULL
			,@IssuetypeId		INT
			,@Reason			VARCHAR(100)

	CREATE TABLE #TmpMatch 
	(
		 RequestId INT
		,Homeid INT
		,Awayid INT
		,Leagueid INT
		,RequestedBy INT
		,DecidedBy NVARCHAR(200)
		,KickOffTime DATETIME
	)
	
	CREATE TABLE #tmpTicket
    (		
		 RequestId		  INT
		,TransId          BIGINT
        ,matchid          INT
        ,custid           INT
        ,Status           NVARCHAR(10)
		,VoidedTime       DATETIME
        ,Bettype          SMALLINT
        ,IsMixParlay      BIT DEFAULT(0)
        ,Refno            BIGINT
        ,subTransId       BIGINT
        ,recommend        INT
		,VoidedBy		  INT
		,VoidingHistoryId INT
		,LicenseeName	  NVARCHAR(100)
		,Total			  INT
    );
	DECLARE @tmpVoidingHistory TABLE ( VoidingHistoryId INT,VoidData XML, VoidedBy INT, VoidResults XML, IsFinish BIT)
	DECLARE @tmpContentMessage TABLE ( RequestId INT,VoidingHistoryId INT, ContentChineseSimplified NVARCHAR(4000), ContentEnglish NVARCHAR(4000))
	DECLARE @tmpVoidResults TABLE ( VoidingHistoryId INT, Message VARCHAR(MAX), Type VARCHAR(50))

	SELECT @IssuetypeId = r.IssueTypeId
		  ,@Reason = s.SubIssueTypeName
	FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_SubIssueType s WITH(NOLOCK) 
		ON r.IssueTypeId = s.IssueTypeId AND r.SubIssueTypeId = s.SubIssueTypeId
	WHERE r.RequestId = @RequestId

	INSERT INTO #TmpMatch (RequestId, Homeid, Awayid, Leagueid, RequestedBy, DecidedBy, KickOffTime)
	SELECT TOP 1 
			 rd.RequestId
			,m.homeid
			,m.awayid
			,m.leagueid
			,r.UserId
			,r.DecidedBy
			,rd.kickofftime
	FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK) ON rd.RequestId = r.RequestId
		LEFT JOIN dbo.match m WITH(NOLOCK) ON rd.MatchId = m.matchid
	WHERE rd.RequestId = @RequestId AND (rd.MatchId = @MatchId OR @MatchId = 0)
	
	IF NOT EXISTS ( SELECT TOP 1 1 FROM #TmpMatch)
	BEGIN
		SET @IsMovebet = 1
	END

	INSERT INTO @tmpVoidingHistory(VoidingHistoryId, VoidData, VoidedBy, VoidResults) 
	SELECT	 VoidingHistoryId
			,VoidData
			,UserId AS VoidedBy
			,s.VoidResults
	FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
	LEFT JOIN Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) ON vh.RequestId = s.RequestID AND vh.VoidingHistoryId = s.VoidingHistory
	WHERE	vh.RequestId = @RequestId AND vh.StatusId IN (2,3)

	-- single ticket
	INSERT INTO #tmpTicket (RequestId,TransId, matchid, Status, VoidedTime, custid, Refno, Bettype, VoidedBy, VoidingHistoryId)
	SELECT	@RequestId
			,z.transid			
			,z.matchid
			,z.status
			,z.VoidedTime
			,z.custid
			,z.refno
			,z.bettype
			,vh.VoidedBy
			,vh.VoidingHistoryId
	FROM	@tmpVoidingHistory vh 
		CROSS APPLY (
			SELECT	z.transid
					,z.matchid
					,z.status
					,z.transdate AS VoidedTime
					,z.custid
					,z.refno
					,z.bettype
			FROM	dbo.zzzbettrans z WITH(NOLOCK)
			WHERE	z.VoidingHistoryId = vh.VoidingHistoryId
					AND (z.matchid = @MatchId OR @MatchId = 0)
					AND 1 = CASE
								WHEN z.bettype = 911 THEN 1
								WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
								ELSE 0
							END
		) z	

	-- parlay ticket
	INSERT INTO #tmpTicket (RequestId, subTransId, matchid, Refno, Status, VoidedTime, custid, IsMixParlay, VoidedBy, VoidingHistoryId)
	SELECT	@RequestId
			,zm.transid		
			,zm.matchid
			,zm.refno
			,zm.status
			,zm.VoidedTime
			,zm.custid
			,1 AS IsMixParlay
			,vh.VoidedBy
			,vh.VoidingHistoryId
	FROM	@tmpVoidingHistory vh
		CROSS APPLY (
			SELECT	zm.transid
					,zm.matchid
					,zm.refno 
					,zm.status
					,zm.transdate AS VoidedTime
					,zm.custid
			FROM	dbo.zzzbettransm zm WITH(NOLOCK)
			WHERE	zm.VoidingHistoryId = vh.VoidingHistoryId
					AND (zm.matchid = @MatchId OR @MatchId = 0)
		) zm

	IF @IsMovebet = 0
	BEGIN
		UPDATE t 
		SET recommend = b.recommend
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans b WITH(NOLOCK) ON	t.TransId = b.transid

		UPDATE t 
		SET transid = b.transid,
			recommend = b.recommend
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm bm WITH(NOLOCK) ON t.subTransId = bm.transid
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29
		
		UPDATE t
		SET LicenseeName = c.site
		FROM #tmpTicket t
			INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON t.recommend = c.custid
	END
	ELSE
	BEGIN
		UPDATE t 
		SET		recommend = b.recommend
		FROM	#tmpTicket t
			INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON	t.TransId = b.transid

		UPDATE t 
		SET		transid = b.transid
				,recommend = b.recommend
		FROM	#tmpTicket t
			INNER LOOP JOIN dbo.bettransm14 bm WITH(NOLOCK) ON t.subTransId = bm.transid
			INNER HASH JOIN dbo.bettrans b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29
		
		IF EXISTS (SELECT TOP 1 1 FROM #tmpTicket WHERE TransId IS NULL AND IsMixParlay = 1)
		BEGIN
			UPDATE	t
				SET transid = b.transid
					,recommend = b.recommend
			FROM	#tmpTicket t
				INNER JOIN dbo.bettransm14 bm WITH(NOLOCK) ON	t.subTransId = bm.transid
				INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON bm.refno = b.refno AND b.matchid = 29 AND b.bettype = 29
		END

		UPDATE t
		SET LicenseeName = c.site
		FROM #tmpTicket t
			INNER JOIN custDB.dbo.Customer c WITH (NOLOCK) ON t.recommend = c.custid
	END

	UPDATE t
	SET t.Total = s.Total
	FROM #tmpTicket t
	CROSS APPLY (
				SELECT COUNT(s.TransId) AS Total
				FROM #tmpTicket s
				WHERE t.VoidingHistoryId = s.VoidingHistoryId
				GROUP BY s.VoidingHistoryId
			) s

	WHILE (1=1)
	BEGIN
		UPDATE TOP(1) t
		SET IsFinish = 1
			,@xmlVoidData = T.VoidData
			,@VoidingHistoryId = T.VoidingHistoryId
			,@xmlVoidResults = T.VoidResults
		FROM @tmpVoidingHistory t
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
				,T.C.value('@Type', 'VARCHAR(50)') AS Type
		FROM	@xmlVoidResults.nodes('/VoidResults/VoidResult') as [T](C)
		OPTION (OPTIMIZE FOR (@xmlVoidResults = NULL ))
	END

	SELECT DISTINCT
		 s.VoidingHistoryId
		,s.VoidedTime
		,CAST (m.Homeid AS VARCHAR(10)) + ' - vs - '+ CAST (m.Awayid AS VARCHAR(10)) AS MatchEvent
		,m.leagueid 
		,m.KickOffTime
		,STUFF((SELECT DISTINCT  ',' + CAST( m.LicenseeName AS VARCHAR(20))
							  FROM #tmpTicket m
							  WHERE s.VoidingHistoryId = m.VoidingHistoryId
							  FOR XML PATH ('')
							),1,1,'')
		 AS LicenseeName
		,s.Total AS Total
		,CASE WHEN @IssuetypeId = 11 THEN @Reason
			  ELSE NULL END Reason
		,m.DecidedBy
		,m.RequestedBy
		,s.VoidedBy
		,cm.ContentChineseSimplified
		,cm.ContentEnglish
		,sv.NegativeBalanceUsers
	FROM #tmpTicket s
	INNER JOIN #TmpMatch m ON s.RequestId = m.RequestId
	LEFT JOIN dbo.Ticketvoiding_VoidBetAutomation_Service sv WITH (NOLOCK)  
				ON s.RequestId = sv.RequestID AND s.VoidingHistoryId = sv.VoidingHistory
	LEFT JOIN @tmpContentMessage cm ON cm.RequestId = s.RequestId AND cm.VoidingHistoryId = s.VoidingHistoryId

	SELECT VoidingHistoryId
		  ,Message
		  ,Type
	FROM @tmpVoidResults

	DROP TABLE #TmpMatch
	DROP TABLE #tmpTicket

END