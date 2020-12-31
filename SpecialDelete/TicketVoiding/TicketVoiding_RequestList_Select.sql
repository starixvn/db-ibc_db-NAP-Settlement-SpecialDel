/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Select]
(
	@RequestId		INT				= NULL
	,@MatchId		INT				= NULL
	,@FromDate		DATETIME		= NULL
	,@ToDate		DATETIME		= NULL
	,@IsExcludeTest BIT				= 1
	,@Status		INT				= 0
	,@IssueTypeId	VARCHAR(100)	= NULL
	,@SubIssueType  VARCHAR(100)	= NULL
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: view request [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191113@Max: AdnormalBet TVS [Redmine:#123691]
		- 20200103@Max: Enhance EKO Issue Type - [Redmine: #126418]
		- 20200206@Max: Permission on data - [Redmine: #128014]
		- 20200226@Max: Auto Void Winning Bets - [Redmine: #129184]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200413@Max: [TVS] VIP account [Redmine: #131431]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200602@Charles: Show bettype on manage request [Redmine:#135041]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200819@Max: Issue for Abnormal Bet Request not show bettype [Redmine: #135947]
		- 20200820@Zane: TVS - Enhance for Danger Accept [#140339]
		- 20200820@Max: Action in Manage Request did not show information in TVS system [Redmine: #139933]
		- 20200909@Max: HotFix - TVS - Danger Accept - void single when sub parlay process No. of ticket can not show ticket single [Redmine: #141124]
		- 20200910@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20201019@Zane: TVS - Enhance for Danger Accept - Phase 4 - Fix duplicate request id [Redmine: #143091]
		- 20201106@July: [TVS] - Abnormal Account [Redmine: #143666]

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

	DECLARE	@FilteredBy	TINYINT,
			@moveBetDay14 	SMALLDATETIME,
		    @moveBetDay 	SMALLDATETIME,
			@Winlostdate	DATETIME

	DECLARE @tmpRequest TABLE (RequestId INT)
	DECLARE @tmpIssueType TABLE (IssueTypeId INT)
	DECLARE @tmpMatchVoidingHistory TABLE (
		 RequestId			INT
		,MatchId			INT
		,VoidingHistoryId	INT
		,VoidedBy			INT
		,TotalSingle		INT
		,TotalCashOut		INT
		,TotalParlay		INT
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
		,TotalCashOut	INT
		,FilterBy		TINYINT
		,VoidFromTime	DATETIME
		,VoidToTime		DATETIME
		,FromWinlostDate DATETIME
		,ToWinlostDate	DATETIME
	)
	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

	DECLARE @SubIssueType_tmp TABlE (SubIssueTypeId INT)
	DECLARE @MinEventDate_tmp TABLE (RequestID INT, Eventdate DATETIME)

	SELECT @moveBetDay14 = MIN(winlostdate) 
	FROM dbo.bettrans14 WITH(NOLOCK)

	SELECT @moveBetDay = MIN(winlostdate) 
	FROM dbo.bettrans WITH(NOLOCK)

	INSERT INTO @tmpIssueType (IssueTypeId)
	SELECT DISTINCT val
	FROM dbo.f_SplitString(@IssueTypeId, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	INSERT INTO @SubIssueType_tmp (SubIssueTypeId)
	SELECT	val AS TransId
	FROM	dbo.f_SplitString(@SubIssueType, ',')
	OPTION (maxrecursion 0) 

	SELECT	@FilteredBy = CASE
								WHEN @RequestId IS NOT NULL THEN 1 -- RequestId
								ELSE
									CASE 
										WHEN @MatchId IS NOT NULL THEN 2 -- MatchId
										ELSE 3 -- Fromdate, Todate
									END
							END

	-----------------------------GET eventdate of match---------------------------------------------
	IF (EXISTS (SELECT TOP 1 1 FROM @tmpIssueType WHERE IssueTypeId = 13))
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM TicketVoiding_RequestDetail rd WITH(NOLOCK) 
								   WHERE matchid = 29
								   AND 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
												WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
												WHEN @FilteredBy = 3 THEN 1
												ELSE 0 END
		)
		BEGIN
			SELECT @Winlostdate =  MIN(b.winlostdate)
			FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
				INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) ON rd.RequestId = s.RequestId
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON rd.MatchId = b.matchid AND s.TransId = b.transid
			WHERE rd.matchid = 29

			IF (@Winlostdate >= @moveBetDay)
			BEGIN
				INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
				SELECT  rd.RequestId,MIN(b.winlostdate)
				FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
					INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) ON rd.RequestId = s.RequestId
					INNER JOIN dbo.bettrans b WITH(NOLOCK) ON rd.MatchId = b.matchid AND s.TransId = b.transid
				WHERE rd.matchid = 29
				AND 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
						   WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
						   WHEN @FilteredBy = 3 AND b.winlostdate BETWEEN @FromDate AND @ToDate  THEN 1
						   ELSE 0 END
				GROUP BY rd.RequestId
			END
			ELSE IF ( @Winlostdate >= @moveBetDay14 AND @Winlostdate < @moveBetDay)
			BEGIN
				INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
				SELECT  rd.RequestId, MIN(b14.winlostdate)
				FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
					INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) ON rd.RequestId = s.RequestId
					INNER JOIN dbo.bettrans14 b14 WITH(NOLOCK) ON rd.MatchId = b14.matchid AND s.TransId = b14.transid
				WHERE rd.matchid = 29
				AND 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
							 WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
							 WHEN @FilteredBy = 3 AND b14.winlostdate BETWEEN @FromDate AND @ToDate  THEN 1
							 ELSE 0 END
				GROUP BY rd.RequestId
			END
		END

		IF EXISTS ( SELECT TOP 1 rd.RequestId, o.eventdate
					FROM TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					INNER JOIN 	(SELECT o.orid, o.eventdate
								 FROM	dbo.outright o WITH(NOLOCK)
								 UNION
								 SELECT	o14.orid, o14.eventdate
								 FROM	dbo.outright14 o14 WITH(NOLOCK)
								)o ON rd.MatchId = o.orid
					WHERE 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
												WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
												WHEN @FilteredBy = 3 AND o.eventdate  BETWEEN @FromDate AND @ToDate THEN 1
												ELSE 0 END
						
					)
		BEGIN
			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  rd.RequestId, MIN(o.eventdate)
			FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
			INNER JOIN
					(SELECT o.orid, o.eventdate
					FROM	dbo.outright o WITH(NOLOCK)
					UNION
					SELECT	o14.orid, o14.eventdate
					FROM	dbo.outright14 o14 WITH(NOLOCK)
					)o ON rd.MatchId = o.orid
			WHERE 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
						   WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
						   WHEN @FilteredBy = 3 AND o.eventdate  BETWEEN @FromDate AND @ToDate THEN 1
						   ELSE 0 END
			GROUP BY rd.RequestId
		END
	END
	
	INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
	SELECT rd.RequestId, MIN(m.eventdate)
	FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
	INNER JOIN
			(
				SELECT m.matchid, m.eventdate
				FROM	dbo.match m WITH(NOLOCK)
				UNION
				SELECT	m14.MatchId, m14.eventdate
				FROM	dbo.match14 m14 WITH(NOLOCK)
			) m
			ON rd.MatchId = m.matchid
	WHERE 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
					WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
					WHEN @FilteredBy = 3 AND m.eventdate  BETWEEN @FromDate AND @ToDate THEN 1
					ELSE 0 END
	GROUP BY rd.RequestId

	IF @FilteredBy = 1
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate)
		SELECT	r.RequestId
				,r.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,rd.MatchId
				,r.Sporttype
				,rd.LeagueId
				,rd.HomeId
				,rd.AwayId
				,rd.KickOffTime
				,m.eventdate
				,rd.TransIds
				,r.IssueTypeId
				,rd.FilterBy
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
		FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
						SELECT DISTINCT RequestID, MIN(m.eventdate) eventdate
						FROM @MinEventDate_tmp m
						GROUP BY RequestID
						)m
				ON r.RequestId = m.RequestID
		WHERE	r.RequestId = @RequestId
					   		
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		INSERT INTO @tmpRequest (RequestId)
		SELECT	DISTINCT rd.RequestId
		FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		WHERE	rd.MatchId = @MatchId

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate)
		SELECT	r.RequestId
				,r.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,rd.MatchId
				,r.Sporttype
				,rd.LeagueId
				,rd.HomeId
				,rd.AwayId
				,rd.KickOffTime
				,m.eventdate
				,rd.TransIds
				,r.IssueTypeId
				,rd.FilterBy
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
		FROM	@tmpRequest t
			INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK)
				ON t.RequestId = r.RequestId
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
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
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE	(@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds,IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate)
		SELECT	r.RequestId
				,r.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,rd.MatchId
				,r.Sporttype
				,rd.LeagueId
				,rd.HomeId
				,rd.AwayId
				,rd.KickOffTime
				,m.eventdate
				,rd.TransIds
				,r.IssueTypeId
				,rd.FilterBy
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
		FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
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
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
	END

	INSERT INTO @tmpMatchVoidingHistory (RequestId, MatchId, VoidingHistoryId, VoidedBy)
	SELECT	vh.RequestId, t.MatchId, vh.VoidingHistoryId, vh.UserId
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
			FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
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
		
	-- single + cash out ticket	
	UPDATE vh 
		SET TotalSingle =	t.TotalVoidedSingle
			,TotalCashOut = t.TotalVoidedCashOut
	FROM @tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,vh.MatchId
					,SUM(CASE 
							WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
							WHEN z.bettype = 911 THEN 1
							ELSE 0 END
						) AS TotalVoidedSingle
					,0 AS TotalVoidedCashOut 
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId, vh.MatchId
	) t 
		ON	vh.VoidingHistoryId = t.VoidingHistoryId
			AND vh.MatchId = t.MatchId
		
	--parlay
	UPDATE vh
		SET TotalParlay = TotalVoidedParlay
	FROM	@tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,vh.MatchId
					,COUNT(1) AS TotalVoidedParlay
			FROM	@tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId, vh.MatchId
	) t
		ON	vh.VoidingHistoryId = t.VoidingHistoryId
			AND vh.MatchId = t.MatchId

	UPDATE t 
		SET TotalSingle = ISNULL(vh.TotalSingle,0)
			,TotalCashOut = ISNULL(vh.TotalCashOut,0)
			,TotalParlay = ISNULL(vh.TotalParlay,0)
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	SUM(vh.TotalSingle) AS TotalSingle
					,SUM(vh.TotalCashOut) AS TotalCashOut
					,SUM(vh.TotalParlay) AS TotalParlay
			FROM	@tmpMatchVoidingHistory vh
			WHERE	vh.RequestId = t.RequestId
					AND vh.MatchId = t.MatchId
		) vh

	--Return Data
	SELECT	DISTINCT t.RequestId
			,t.SubIssueTypeId
			,CASE WHEN t.IssueTypeId <> 13 THEN t.MatchId ELSE NULL END AS MatchId
			,CASE WHEN t.IssueTypeId <> 13 THEN t.KickOffTime ELSE NULL END AS KickOffTime
			,CASE WHEN t.IssueTypeId <> 13 THEN t.Sporttype ELSE NULL END AS Sporttype
			,CASE WHEN t.IssueTypeId <> 13 THEN t.LeagueId ELSE NULL END AS LeagueId
			,CASE WHEN t.IssueTypeId <> 13 THEN t.HomeId ELSE NULL END AS HomeId
			,CASE WHEN t.IssueTypeId <> 13 THEN t.AwayId ELSE NULL END AS AwayId
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
			,CASE WHEN t.IssueTypeId = 11 THEN ts.TotalSingle ELSE 0 END AS TotalSingle
			,CASE WHEN t.IssueTypeId = 11 THEN ts.TransIds ELSE NULL END AS TransIds
			,t.IssueTypeId
			,CASE WHEN s.statusID NOT IN (1,2,3,12,13) THEN ''
				WHEN s.statusID IN (1,2) THEN 'Running'
				WHEN s.statusID = 12 THEN 'Completed'
				WHEN s.statusID IN (3,13) THEN 'Failed'
				ELSE NULL END AS Status
			,t.FilterBy
			,t.VoidFromTime
			,t.VoidToTime
			,t.FromWinlostDate
			,t.ToWinlostDate
			,CASE WHEN t.IssueTypeId = 13 THEN us.TotalUserName ELSE 0 END AS TotalUserName --no.of accounts
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN CustDB.dbo.Customer ch WITH(NOLOCK)
			ON t.CheckedBy = ch.CustId
		OUTER APPLY (
					SELECT COUNT(1) AS TotalSingle
						,STUFF((
							SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
							FROM TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
							WHERE (RequestId = s.RequestId) 
							FOR XML PATH(''))
							,1,1,''
						) AS TransIds
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
					WHERE s.RequestId = t.RequestId
					GROUP BY s.RequestId
			)ts
		OUTER APPLY (
					SELECT (LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1) AS  TotalUserName
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
					WHERE rd.RequestId = t.RequestId
					)us
		OUTER APPLY (
					SELECT TOP 1 RequestId, statusID
					FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					WHERE s.RequestId = t.RequestID
					ORDER BY VoidingHistory DESC 
					)s

	WHERE 1 = CASE 
				WHEN @Status = -1 THEN 1
				WHEN @Status = 0 AND s.statusID NOT IN (1,2,3,12,13) THEN 1
				WHEN @Status = 1 AND s.statusID IN (1,2) THEN 1 --Running
				WHEN @Status = 2 AND s.statusID = 12 THEN 1 -- Completed
				WHEN @Status = 3 AND s.statusID IN (3,13) THEN 1 -- Failed
				ELSE 0
			END	
	ORDER BY t.RequestId DESC
	
	DROP TABLE #tmpResult
	
END
