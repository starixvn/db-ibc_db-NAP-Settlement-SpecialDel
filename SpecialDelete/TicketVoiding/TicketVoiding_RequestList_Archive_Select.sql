/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Archive_Select]
(
	 @RequestIdXml	XML				= NULL
	,@MatchId		INT				= NULL
	,@IsExcludeTest BIT				= 1
	,@Status		INT				= 0
	,@IssueTypeId	VARCHAR(100)	= NULL
	,@SubIssueType  VARCHAR(MAX)	= NULL
	,@RequestId		INT				= NULL
	,@CreatedBy		INT				= 0
)
AS
/*	Created by: Zane
	Date 20200811
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

	Param's explanation:	
		@Status: 
			--1: All
			- 0: New
			- 1: Running
			- 2: Completed
			- 3: Failed
		@RequestIdXml : <RequestId Id="1"/><RequestId Id="2"/>
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@FilteredBy			TINYINT

	DECLARE @tmpRequest TABLE (RequestId INT)
	DECLARE @tmpIssueType TABLE (IssueTypeId INT)
	DECLARE @tmpMatchVoidingHistory TABLE (
		RequestId			INT
		,VoidingHistoryId	INT
		,VoidedBy			INT
		,TotalSingle		INT
		,TotalParlay		INT
		,MatchId			INT
		,IssueTypeId		INT
	)

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
		,TotalSingle	INT
		,TotalParlay	INT
		,VoidFromTime	DATETIME
		,VoidToTime		DATETIME
		,FromWinlostDate DATETIME
		,ToWinlostDate	DATETIME
		,TotalUserName	INT
		,WrongScores	VARCHAR(MAX)
		,FilterBy		TINYINT
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

	IF @RequestIdXml IS NOT NULL
	BEGIN
		-- Parse xml @RequestId
		INSERT INTO @tmpRequest(RequestId)
		SELECT t.c.value('@Id','INT') AS RequestId
		FROM @RequestIdXml.nodes('RequestId') t(c)
		OPTION (OPTIMIZE FOR (@RequestIdXml = NULL))
	END

	SELECT	@FilteredBy = CASE
								WHEN @RequestId IS NOT NULL THEN 1 -- RequestId
								WHEN @MatchId IS NOT NULL THEN 2 -- MatchId
								WHEN @RequestIdXml IS NOT NULL THEN 3 -- Fromdate, Todate

							END
	-----------------------------GET eventdate of match---------------------------------------------
	IF (EXISTS (SELECT TOP 1 1 FROM @tmpIssueType WHERE IssueTypeId IN (11,13,17)))
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
										LEFT JOIN @tmpRequest r 
											ON rd.RequestId = r.RequestId 
								   WHERE matchid IN (9, 29, 2799)
								   AND 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
												WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
												WHEN @FilteredBy = 3 AND r.RequestId IS NOT NULL THEN 1
												ELSE 0 END
		)
		BEGIN
			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  rd.RequestId, MIN(bk.winlostdate)
			FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH(NOLOCK) 
					ON rd.RequestId = s.RequestId AND rd.MatchId = s.MatchId
				INNER JOIN dbo.bettrans_bk bk WITH(NOLOCK) 
					ON rd.MatchId = bk.matchid AND s.TransId = bk.transid
				LEFT JOIN @tmpRequest r 
					ON rd.RequestId = r.RequestId 
			WHERE rd.matchid IN (9, 29, 2799)
			AND 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
						 WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
						 WHEN @FilteredBy = 3 AND r.RequestId IS NOT NULL THEN 1
						 ELSE 0 END
			GROUP BY rd.RequestId
		END
		IF EXISTS ( SELECT TOP 1 rd.RequestId, o.eventdate
					FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK) 
						INNER JOIN dbo.outright_bk o WITH(NOLOCK) ON rd.MatchId = o.orid
						LEFT JOIN @tmpRequest r ON rd.RequestId = r.RequestId 
					WHERE 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
								   WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
								   WHEN @FilteredBy = 3 AND r.RequestId IS NOT NULL THEN 1
								   ELSE 0 END
					)
		BEGIN
			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  rd.RequestId, MIN(o.eventdate)
			FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				INNER JOIN dbo.outright_bk o WITH(NOLOCK) 
					ON rd.MatchId = o.orid
				LEFT JOIN @tmpRequest r 
					ON rd.RequestId = r.RequestId 
			WHERE 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
						   WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
						   WHEN @FilteredBy = 3 AND r.RequestId IS NOT NULL THEN 1
						   ELSE 0 END
			GROUP BY rd.RequestId
		END
	END
	
	INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
	SELECT rd.RequestId, MIN(m.eventdate)
	FROM TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
		INNER JOIN dbo.match_bk m WITH(NOLOCK) 
			ON rd.MatchId = m.matchid
		LEFT JOIN @tmpRequest r 
			ON rd.RequestId = r.RequestId 
	WHERE 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
				   WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
				   WHEN @FilteredBy = 3 AND r.RequestId IS NOT NULL THEN 1
				   ELSE 0 END
	GROUP BY rd.RequestId

	IF @FilteredBy = 1
	BEGIN
	INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, FilterBy)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17) THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,m.eventdate
				,CASE WHEN r.IssueTypeId = 3 THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.FilterBy
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

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, FilterBy)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17) THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,m.eventdate
				,CASE WHEN r.IssueTypeId = 3 THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.FilterBy
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
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, FilterBy)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17) THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17) OR (r.IssueTypeId = 11 AND rd.FilterBy = 1) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,m.eventdate
				,CASE WHEN r.IssueTypeId = 3 THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.FilterBy
		FROM	dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
						SELECT DISTINCT RequestID, MIN(m.eventdate) eventdate
						FROM @MinEventDate_tmp m
						GROUP BY RequestID
						)m
				ON r.RequestId = m.RequestID
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

	INSERT INTO @tmpMatchVoidingHistory (RequestId, VoidingHistoryId, VoidedBy, IssueTypeId)
	SELECT DISTINCT	vh.RequestId, vh.VoidingHistoryId, vh.UserId, t.IssueTypeId
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
			FROM	@tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId
			ORDER BY vh.VoidingHistoryId DESC
		) vh
		
	-- single ticket	
	UPDATE vh 
		SET TotalSingle = t.TotalVoidedSingle
			,MatchId = t.matchid
			,TotalParlay = CASE WHEN vh.IssueTypeId IN (11,13,17) THEN t.TotalVoidedParlay ELSE 0 END
	FROM @tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,SUM( CASE 
							WHEN vh.IssueTypeId NOT IN (11,13,17) THEN 1
							WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype NOT IN (9,29,2799) THEN 1
						ELSE 0 END
					) AS TotalVoidedSingle
					,SUM(CASE WHEN vh.IssueTypeId IN (11,13,17) AND z.bettype IN(9,29,2799) THEN 1 ELSE 0 END) AS TotalVoidedParlay
					,CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END AS matchid
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans_bk z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId, CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE z.matchid END 
	) t 
		ON	vh.VoidingHistoryId = t.VoidingHistoryId
		
	--parlay
	UPDATE vh
		SET TotalParlay = TotalVoidedParlay
			,MatchId = t.matchid
	FROM	@tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,COUNT(1) AS TotalVoidedParlay
					,CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE zm.matchid END AS matchid
			FROM	@tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm_bk zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId, CASE WHEN vh.IssueTypeId IN (13,17) THEN 0 ELSE zm.matchid END 
	) t
		ON	vh.VoidingHistoryId = t.VoidingHistoryId

	UPDATE t 
		SET TotalSingle = ISNULL(vh.TotalSingle,0)
			,TotalParlay = ISNULL(vh.TotalParlay,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	SUM(vh.TotalSingle) AS TotalSingle
					,SUM(vh.TotalParlay) AS TotalParlay
			FROM	@tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR vh.MatchId = 0)
		) vh

	--Return Data
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
			,t.TotalSingle AS TotalVoidedSingle
			,t.TotalParlay AS TotalVoidedParlay
			,CASE WHEN t.IssueTypeId IN (11,15,17) THEN LEN(ISNULL(ts.TransIds,'')) - LEN(REPLACE(ISNULL(ts.TransIds,''), ',', ''))  ELSE 0 END AS TotalSingle
			,CASE WHEN t.IssueTypeId IN (17) THEN LEN(ISNULL(p.TransIds,'')) - LEN(REPLACE(ISNULL(p.TransIds,''), ',', ''))  ELSE 0 END AS TotalParlay
			,CASE WHEN t.IssueTypeId IN (11,15) THEN STUFF(ts.TransIds,1,1,'') ELSE NULL END AS TransIds
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
			,CASE WHEN t.IssueTypeId IN (1,10,3) THEN t.TransIds ELSE NULL END AS IsCheckedVar
	FROM	#tmpResult t
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN bodb02.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN bodb02.dbo.Customer ch WITH(NOLOCK)
			ON t.CheckedBy = ch.CustId
		OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
					FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)
					WHERE s.RequestId = t.RequestId
					AND 1 = CASE WHEN t.IssueTypeId IN (11,15) THEN 1
								 WHEN t.IssueTypeId IN (17) AND s.MatchId NOT IN (9,29,2799) THEN 1
								 ELSE 0 END
					FOR XML PATH('')
				)ts	 (TransIds)
		OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
					FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)
					WHERE s.RequestId = t.RequestId AND t.IssueTypeId IN (17) AND s.MatchId IN (9,29,2799)
					FOR XML PATH('')
				)p	 (TransIds)
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
	
	DROP TABLE #tmpResult
	
END
