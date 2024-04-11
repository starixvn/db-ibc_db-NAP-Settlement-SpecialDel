/*<info serverAlias="DBARC-bodb_Archive" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Archive_Select]
(
	 @RequestInfoJson	VARCHAR(MAX)	= NULL
	,@MatchId			INT				= NULL
	,@IsExcludeTest		BIT				= 1
	,@Status			INT				= 0
	,@IssueTypeId		VARCHAR(MAX)	= NULL
	,@SubIssueType		VARCHAR(MAX)	= NULL
	,@RequestId			INT				= NULL
	,@CreatedBy			INT				= 0
)
AS
/*	Created by: 20200811@Zane
	Task: Edit SP for new change of Archive process [Redmine:#139208]
	DB: DBARC/bodb_Archive
	
	Revisions:		
		- 20200811@Zane: Archive process for Ticket Voiding tables [Redmine:#111093]
		- 20201120@Zane: HF - Manage Request [Redmine:#145756]
		- 20201223@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210202@July: Modify process for abnormal Account [Redmine:#149776]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210414@July: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210602@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210608@July: Search request with Exclude Istest but can still display Request istest = 1 [Redmine: #154988]
		- 20210625@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20211013@Max: [TVS] Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211118@July: Change length datatatype [Redmine:#164819]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220113@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220225@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
		- 20220404@Max: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221026@July: TVS - VAR message [Redmine: #178088]
		- 20230220@July: Cancel Cash-Out if action CO in danger time range [Redmine: #176998]
		- 20230419@Max: [TVS] New issue type Wrong Odds [Redmine: #179934]
		- 20230522@July: Manage Request - Add more columns to the export excel template [Redmine:#188153]
		- 20230608@Max: [TVS] Support void Cricket when reducing over [Redmine: #185833]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20231016@Max: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240307@July: [TVS] Abnormal Bet - Support void System Parlay tickets [Redmine: #196462]
		- 20240319@July: [TVS] SP tuning for EC2024 [Redmine: #200840]

	Param's explanation:	
		@Status: 
			--1: All
			- 0: New
			- 1: Running
			- 2: Completed
			- 3: Failed
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@FilteredBy			TINYINT
	       ,@RequestInfoGetCalcTimes VARBINARY(MAX) = NULL

	DECLARE @tmpRequest TABLE (RequestId INT, Eventdate DATETIME)
	DECLARE @tmpIssueType TABLE (IssueTypeId INT)
	DECLARE @tmpChildMatchCricket TABLE (
		RequestId		INT
	   ,MatchId			INT
	   ,ChildMatchId	INT
	)
    
	CREATE TABLE #tmpMatchVoidingHistory (
		 RequestId			INT
		,VoidingHistoryId	INT
		,VoidedBy			INT
		,TotalSingleProcessed	INT DEFAULT (0)
		,TotalParlayProcessed	INT DEFAULT (0)
		,TotalCancelCashOutProcessed INT DEFAULT (0)
		,MatchId			INT
		,IssueTypeId		INT
	)
	CREATE NONCLUSTERED INDEX IX_tmpMatchVoidingHistory_VoidingHistoryId ON #tmpMatchVoidingHistory (VoidingHistoryId)
	 
	CREATE TABLE #tmpResult (
		RequestId		INT
		,SubIssueTypeId SMALLINT
		,ActionId		TINYINT
		,UserId			INT
		,CreatedDate	DATETIME
		,MistakenBy		NVARCHAR(200)
		,DecidedBy		NVARCHAR(200)
		,CheckedBy		INT
		,MatchId		INT
		,Sporttype		SMALLINT
		,LeagueId		INT
		,HomeId			INT
		,AwayId			INT
		,KickOffTime	DATETIME
		,EventDate		DATETIME
		,TransIds		VARCHAR(MAX)
		,IssueTypeId	TINYINT
		,LastVoidedBy	INT
		,VoidFromTime	DATETIME
		,VoidToTime		DATETIME
		,FromWinlostDate DATETIME
		,ToWinlostDate	DATETIME
		,TotalUserName	INT
		,WrongScores	VARCHAR(MAX)
		,FilterBy		TINYINT
		,ProductIds		VARCHAR(50)
		,TotalSingleProcessed	INT
		,TotalParlayProcessed	INT
		,TotalCancelCashOutProcessed INT
		,TotalResettleProcessed INT
	)
	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

	DECLARE @SubIssueType_tmp TABlE (SubIssueTypeId INT)
	DECLARE @MinEventDate_tmp TABLE (RequestID INT, Eventdate DATETIME)

	INSERT INTO @tmpIssueType (IssueTypeId)
	SELECT DISTINCT value AS IssueTypeId
	FROM STRING_SPLIT(@IssueTypeId, ',')

	INSERT INTO @SubIssueType_tmp (SubIssueTypeId)
	SELECT	value AS SubIssueTypeId
	FROM STRING_SPLIT(@SubIssueType, ',')

	SELECT	@FilteredBy = CASE
							  WHEN @RequestId IS NOT NULL THEN 1 -- RequestId
							  WHEN @MatchId IS NOT NULL THEN 2 -- MatchId
							  WHEN @RequestInfoJson IS NOT NULL THEN 3 -- Fromdate, Todate
						  END
	-----------------------------GET eventdate of match---------------------------------------------
	IF @FilteredBy = 1
	BEGIN
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT  s.RequestId, MIN(s.Winlostdate)
		FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK) 
		WHERE s.MatchId IN (9, 29, 2799, 10449) 
			AND s.RequestId = @RequestId
		GROUP BY s.RequestId

		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT  rd.RequestId, MIN(o.eventdate)
		FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
			INNER JOIN dbo.outright_bk o WITH(NOLOCK) ON rd.MatchId = o.orid
		WHERE rd.RequestId = @RequestId
		GROUP BY rd.RequestId
	
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT rd.RequestId, MIN(m.eventdate)
		FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
			INNER JOIN dbo.match_bk m WITH(NOLOCK) ON rd.MatchId = m.matchid
		WHERE rd.RequestId = @RequestId
		GROUP BY rd.RequestId
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		IF @MatchId IN (9, 29, 2799, 10449)
		BEGIN
			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  s.RequestId, MIN(s.Winlostdate)
			FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK) 
			WHERE s.MatchId IN (9, 29, 2799, 10449) 
				AND s.MatchId = @MatchId
			GROUP BY s.RequestId
		END

		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT  rd.RequestId, MIN(o.eventdate)
		FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
			INNER JOIN dbo.outright_bk o WITH(NOLOCK) ON rd.MatchId = o.orid
		WHERE rd.MatchId = @MatchId
		GROUP BY rd.RequestId
	
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT rd.RequestId, MIN(m.eventdate)
		FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
			INNER JOIN dbo.match_bk m WITH(NOLOCK) ON rd.MatchId = m.matchid
		WHERE rd.MatchId = @MatchId
		GROUP BY rd.RequestId
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO @tmpRequest(RequestId, Eventdate)
		SELECT req, e
		FROM STRING_SPLIT(@RequestInfoJson, ',') f
			CROSS APPLY (SELECT CAST(DECOMPRESS(CONVERT(VARBINARY(MAX), f.value, 1)) AS NVARCHAR(MAX)) AS Decompress_RequestInfo) t
			CROSS APPLY (
					SELECT req, e
					FROM OPENJSON(t.Decompress_RequestInfo) 
					WITH( req INT, e DATETIME)
				)tbl
		WHERE f.value <> ''

	END
	----------------------------- End of EventDate Processing ------------------------------
	IF @FilteredBy = 1
	BEGIN
	INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, FilterBy, ProductIds)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,m.eventdate
				,CASE WHEN r.IssueTypeId IN (3,19,21) THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.FilterBy
				,rd.ProductIds
		FROM dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
						SELECT DISTINCT RequestID, MIN(m.eventdate) eventdate
						FROM @MinEventDate_tmp m
						GROUP BY RequestID
						)m
				ON r.RequestId = m.RequestID
			OUTER APPLY(
						SELECT '|' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE	r.RequestId = @RequestId
					   		
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		INSERT INTO @tmpRequest (RequestId)
		SELECT	DISTINCT rd.RequestId
		FROM	dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
		WHERE	rd.MatchId = @MatchId

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, FilterBy, ProductIds)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,m.eventdate
				,CASE WHEN r.IssueTypeId IN (3,19,21) THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.FilterBy
				,rd.ProductIds
		FROM	@tmpRequest t
			INNER JOIN dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
				ON t.RequestId = r.RequestId
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
						SELECT DISTINCT RequestID, MIN(m.eventdate) eventdate
						FROM @MinEventDate_tmp m
						GROUP BY RequestID
						)m
				ON rd.RequestID = m.RequestID
			INNER JOIN @tmpIssueType tmp 
				ON tmp.IssueTypeId = r.IssueTypeId
			INNER JOIN @SubIssueType_tmp sub
				ON sub.SubIssueTypeId = rd.SubIssueTypeId
			OUTER APPLY(
						SELECT '|' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE	(@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0
			AND ((r.UserId = @CreatedBy) OR @CreatedBy = 0)
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, FilterBy, ProductIds)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,t.eventdate
				,CASE WHEN r.IssueTypeId IN (3,19,21) THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.FilterBy
				,rd.ProductIds
		FROM @tmpRequest t
			INNER JOIN dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
				ON t.RequestId = r.RequestId
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN @tmpIssueType tmp 
				ON tmp.IssueTypeId = r.IssueTypeId
			INNER JOIN @SubIssueType_tmp sub
				ON sub.SubIssueTypeId = rd.SubIssueTypeId
			OUTER APPLY(
						SELECT '|' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
			AND ((r.UserId = @CreatedBy) OR @CreatedBy = 0)
	END

	UPDATE t
	SET t.TransIds = rd.TransIds
	FROM #tmpResult t 
		CROSS APPLY (
				SELECT TOP (1) rd.TransIds
				FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				WHERE t.Requestid = rd.RequestId
			)rd
	WHERE t.IssueTypeId = 3

	INSERT INTO #tmpMatchVoidingHistory (RequestId, VoidingHistoryId, VoidedBy, IssueTypeId, MatchId)
	SELECT DISTINCT	vh.RequestId, vh.VoidingHistoryId, vh.UserId, t.IssueTypeId, ISNULL(t.MatchId,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
			FROM	dbo.TicketVoiding_VoidingHistory_bk vh WITH(NOLOCK)
			WHERE	vh.RequestId = t.requestId AND vh.StatusId IN (2,3)
		) vh
		
	UPDATE	t 
		SET LastVoidedBy = vh.LastVoidedBy
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	TOP (1) vh.VoidedBy AS LastVoidedBy
			FROM	#tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId
			ORDER BY vh.VoidingHistoryId DESC
		) vh
	
	IF EXISTS (SELECT TOP 1 1 FROM #tmpResult WHERE Sporttype = 50)
	BEGIN
		INSERT INTO @tmpChildMatchCricket (RequestId, MatchId, ChildMatchId)
		SELECT t.RequestId, t.MatchId, m.matchid
		FROM #tmpResult t 
			INNER JOIN dbo.match_bk m WITH (NOLOCK) ON m.ParentID = t.MatchId  
		WHERE t.Sporttype = 50  
			AND m.sporttype = 50 AND m.ChildMatchType = 200
	END

	-- single ticket	
	;WITH CTE_Single AS(
			SELECT	vh.VoidingHistoryId
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (1,10,3) AND z.bettype NOT IN (9,29,2799,10449) THEN 1
							WHEN vh.IssueTypeId IN (1,10,3) AND ISNULL(z.comstatus,'') <> 'CO' THEN 1
						ELSE 0 END
					) AS TotalSingleProcessed
					,SUM(CASE WHEN z.bettype IN (9,29,2799,10449) THEN 1 ELSE 0 END) AS TotalParlayProcessed
					,CASE WHEN vh.MatchId = 0 THEN 0 ELSE ISNULL(m.matchid, z.matchid) END AS matchid
					,SUM(CASE WHEN vh.IssueTypeId IN (1,10,3) AND z.comstatus = 'CO' THEN 1 ELSE 0 END) AS TotalCancelCashOutProcessed -- Apply for DA,RC,WC
			FROM #tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans_bk z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId AND z.VoidingHistoryId IS NOT NULL
				LEFT JOIN @tmpChildMatchCricket m ON z.matchid = m.ChildMatchId
			WHERE vh.IssueTypeId NOT IN (22) --Recover Ticket
				 AND (vh.MatchId = CASE WHEN m.MatchId IS NOT NULL THEN m.MatchId ELSE z.matchid END
                        OR vh.MatchId = 0)
			GROUP BY vh.VoidingHistoryId
				   , CASE WHEN vh.MatchId = 0 THEN 0 ELSE ISNULL(m.matchid, z.matchid) END 
	)
	UPDATE vh 
		SET TotalSingleProcessed = t.TotalSingleProcessed
			,TotalParlayProcessed = t.TotalParlayProcessed
			,TotalCancelCashOutProcessed = t.TotalCancelCashOutProcessed
	FROM #tmpMatchVoidingHistory vh
		INNER JOIN CTE_Single t ON vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid
	
	--parlay ticket
	;WITH CTE_Parlay AS(
		SELECT	vh.VoidingHistoryId
					,COUNT(1) AS TotalParlayProcessed
					,ISNULL(m.matchid, zm.matchid) AS matchid
			FROM	#tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm_bk zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId AND zm.VoidingHistoryId IS NOT NULL
				LEFT JOIN @tmpChildMatchCricket m ON zm.matchid = m.ChildMatchId
			WHERE vh.IssueTypeId NOT IN (11,15,13,17,22) --Except AB,AB(real member),AC,ARC,RT
				AND vh.MatchId = CASE WHEN m.MatchId IS NOT NULL THEN m.MatchId ELSE zm.matchid END
			GROUP BY vh.VoidingHistoryId, ISNULL(m.matchid, zm.matchid)
	)
	UPDATE vh
		SET TotalParlayProcessed = t.TotalParlayProcessed
	FROM	#tmpMatchVoidingHistory vh
		INNER JOIN CTE_Parlay t ON vh.VoidingHistoryId = t.VoidingHistoryId AND vh.MatchId = t.matchid  

	UPDATE t 
		SET TotalSingleProcessed = ISNULL(vh.TotalSingleProcessed,0)
			,TotalParlayProcessed = ISNULL(vh.TotalParlayProcessed,0)
			,TotalCancelCashOutProcessed = ISNULL(vh.TotalCancelCashOutProcessed,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	SUM(vh.TotalSingleProcessed) AS TotalSingleProcessed
					,SUM(vh.TotalParlayProcessed) AS TotalParlayProcessed
					,SUM(vh.TotalCancelCashOutProcessed) AS TotalCancelCashOutProcessed
			FROM	#tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR vh.MatchId = 0)
		) vh

	IF EXISTS (SELECT TOP 1 1 FROM #tmpMatchVoidingHistory WHERE IssueTypeId = 22) --Recover Ticket
	BEGIN
		DECLARE @tmp_TransId AS TABLE (RequestId INT, TransId BIGINT, MatchId INT, IsProcessed TINYINT)

		INSERT INTO @tmp_TransId(RequestId, TransId, MatchId, IsProcessed)
		SELECT t.RequestId, s.TransId, s.MatchId, s.IsProcessed
		FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)
			INNER JOIN #tmpResult t ON t.RequestId = s.Requestid
		WHERE s.IsProcessed IS NOT NULL
			AND s.IssueTypeId = 22

		DELETE t
		FROM @tmp_TransId t
			INNER JOIN dbo.zzzbettrans_bk z WITH(NOLOCK) ON t.TransId = z.transid AND z.comstatus <> 'CO'

		UPDATE t 
		SET TotalSingleProcessed = ISNULL(rt.TotalSingleProcessed,0)
		   ,TotalParlayProcessed = ISNULL(rt.TotalParlayProcessed,0)
		   ,TotalResettleProcessed = ISNULL(rt.TotalResettleProcessed,0) 
		FROM	#tmpResult t
		CROSS APPLY (SELECT 
						 SUM(CASE WHEN s.MatchId NOT IN (9,29,2799,10449) THEN 1 ELSE 0 END) AS TotalSingleProcessed
						,SUM(CASE WHEN s.MatchId IN (9,29,2799,10449) THEN 1 ELSE 0 END) AS TotalParlayProcessed
						,SUM(CASE WHEN s.IsProcessed = 2 THEN 1 ELSE 0 END) AS TotalResettleProcessed
					FROM @tmp_TransId s
					WHERE s.RequestId = t.RequestId
				)rt	
		WHERE t.IssueTypeId = 22 --Recover Ticket
	END
	
	/*****************Return table **************************/
	-- 1. Return infor table
	SELECT	t.RequestId
			,t.SubIssueTypeId
			,t.MatchId
			,t.KickOffTime
			,t.Sporttype
			,t.LeagueId
			,t.HomeId
			,t.AwayId
			,t.EventDate
			,t.ActionId
			,t.CreatedDate
			,c.Username AS CreatedBy
			,t.MistakenBy
			,t.DecidedBy
			,v.Username AS LastPerformedBy
			,ch.Username AS CheckedBy
			,cnt.TotalSingle
			,cnt.TotalParlay
			,t.IssueTypeId
			,CASE WHEN f_s.statusID IS NULL AND f_vh.statusID IS NULL AND l_s.statusID IS NULL AND l_vh.statusID IS NULL THEN ''
				  ELSE CASE WHEN ISNULL(f_vh.statusID,f_s.statusID) = 3 THEN 'Failed'
							WHEN l_vh.statusID = 2 AND l_s.statusID = 2 THEN 'Completed'
							ELSE 'Running' END
				  END AS Status
			,t.FilterBy
			,t.VoidFromTime
			,t.VoidToTime
			,t.FromWinlostDate
			,t.ToWinlostDate
			,t.TotalUserName --no.of accounts
			,t.WrongScores
			,mr.SettlementStatus
			,CASE WHEN t.IssueTypeId IN (1,10,3,8,9) THEN t.TransIds ELSE NULL END AS RequestExtraInfo
			,CASE WHEN CHARINDEX('1',t.ProductIds) > 0 THEN 'Sportsbook' ELSE NULL END AS Products -- Apply issuetype Recover Ticket
			,t.TotalSingleProcessed
			,t.TotalParlayProcessed
			,t.TotalCancelCashOutProcessed
			,t.TotalResettleProcessed 
	FROM	#tmpResult t
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN bodb02.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN bodb02.dbo.Customer ch WITH(NOLOCK)
			ON t.CheckedBy = ch.CustId
		OUTER APPLY (SELECT  COUNT(CASE WHEN s.IssueTypeId IN (17) AND s.MatchId NOT IN (9,29,2799,10449) THEN s.TransId 
										WHEN s.IssueTypeId IN (11,15,20) THEN s.TransId 
										ELSE NULL END) AS TotalSingle
							,COUNT(CASE WHEN s.IssueTypeId IN (17) AND s.MatchId IN (9,29,2799,10449) THEN s.TransId ELSE NULL END) AS TotalParlay
					FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)
					WHERE s.RequestId = t.RequestId 
				)cnt	
		---Case Failed
		OUTER APPLY ( 
					SELECT DISTINCT RequestId, vh.StatusId
					FROM dbo.TicketVoiding_VoidingHistory_bk vh WITH(NOLOCK) 
					WHERE vh.RequestId = t.RequestID AND vh.StatusId = 3
				)f_vh
		OUTER APPLY ( 
					SELECT DISTINCT RequestId, s.StatusId
					FROM bodb02.dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					WHERE s.RequestId = t.RequestID AND s.StatusId = 3
				)f_s
				---Case Completed, Running
		OUTER APPLY ( 
					SELECT TOP 1 RequestId, vh.statusID
					FROM dbo.TicketVoiding_VoidingHistory_bk vh WITH(NOLOCK) 
					WHERE vh.RequestId = t.RequestID
					ORDER BY VoidingHistoryId DESC 
				)l_vh
		OUTER APPLY ( 
					SELECT TOP 1 RequestId, statusID
					FROM bodb02.dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					WHERE s.RequestId = t.RequestID
					ORDER BY VoidingHistoryId DESC 
				)l_s	
		OUTER APPLY (
					SELECT matchcode, hthomescore, htawayscore, finalhomescore, finalawayscore
					FROM dbo.match_bk WITH (NOLOCK)
					WHERE matchid = t.MatchId
			)m
		OUTER APPLY(
					SELECT CASE WHEN mr.calculate = 1 THEN 'FT: ' + CAST(m.finalhomescore AS VARCHAR(10)) + '-' + CAST(finalawayscore AS VARCHAR(10))
								WHEN mr.IsHTCal = 1 THEN 'HT: ' + CAST(m.hthomescore AS VARCHAR(10)) + '-' + CAST(m.htawayscore AS VARCHAR(10))
							ELSE 'HT: _-_' END AS SettlementStatus
					FROM dbo.match_remark mr WITH (NOLOCK) 
					WHERE mr.matchid = t.MatchId
			)mr
		WHERE 1 = CASE 
				--All
				WHEN @Status = -1 THEN 1
				--New
				WHEN @Status = 0 AND f_s.statusID IS NULL AND f_vh.statusID IS NULL AND l_s.statusID IS NULL AND l_vh.statusID IS NULL THEN 1 
				--Completed
				WHEN @Status = 2 AND l_vh.statusID = 2 AND l_s.statusID = 2 THEN 1 
				--Failed
				WHEN @Status = 3 AND ISNULL(f_vh.statusID,f_s.statusID) = 3 THEN 1 
				--Running
				WHEN @Status = 1 AND (l_vh.statusID IS NOT NULL AND l_vh.statusID NOT IN (2,3) AND l_s.statusID IS NULL) THEN 1 
				WHEN @Status = 1 AND (l_s.statusID IS NOT NULL AND l_s.statusID NOT IN (2,3) AND l_vh.statusID IS NULL) THEN 1 
				WHEN @Status = 1 AND (l_vh.statusID IS NOT NULL AND l_s.statusID NOT IN (2,3) AND l_vh.statusID NOT IN (2,3) AND l_s.statusID IS NOT NULL) THEN 1 
				ELSE 0
			END	
	ORDER BY t.RequestId DESC, CASE WHEN t.IssueTypeId IN (1,4,5,6,7) THEN m.matchcode ELSE NULL END
	
	-- 2. Support get calculate time for Issuetype Abnormal Bet (Single ticket) + AB (Real Member) 
	DECLARE @tmpGetInfo TABLE (RequestId INT, Sporttype SMALLINT, MatchId INT)
	INSERT INTO @tmpGetInfo (RequestId, Sporttype, MatchId)
	SELECT RequestId, Sporttype, MatchId
	FROM #tmpResult
	WHERE 1 = CASE WHEN IssueTypeId IN (11) AND FilterBy IS NULL THEN 1 
				   WHEN IssueTypeId = 15 THEN 1
				   ELSE 0 END 

	SET @RequestInfoGetCalcTimes = COMPRESS((SELECT RequestId AS 'req'
		  ,Sporttype AS 's'
		  ,MatchId AS 'mid'
	FROM @tmpGetInfo
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfoGetCalcTimes, 1) AS RequestInfoGetCalcTimes

	-- 3. Support get bettype name for Issuetype Abnormal Bet (Single ticket) + AB (Real Member) [#135041]
	SELECT t.RequestId, s.Bettype, CASE WHEN f.IsNameXBettype = 1 THEN s.BetId ELSE NULL END AS BetId
	FROM @tmpGetInfo t
		CROSS APPLY ( 
				SELECT DISTINCT s.Bettype, s.betid
				FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)
				WHERE s.RequestId = t.RequestId 
		)s
		OUTER APPLY (
			SELECT	TOP 1 f.IsNameXBettype
			FROM	dbo.f_SD_GetGroupBettypes () f
			WHERE	f.bettype = s.Bettype
		)f
	GROUP BY t.RequestId, s.Bettype, CASE WHEN f.IsNameXBettype = 1 THEN s.BetId ELSE NULL END
	ORDER BY s.Bettype DESC

	DROP TABLE #tmpResult
	DROP TABLE #tmpMatchVoidingHistory
END
