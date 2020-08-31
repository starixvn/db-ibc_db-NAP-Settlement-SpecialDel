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
		- 20200820@Zane: Change filter of manage request by the created date of request. [Redmine: #140000]
		- 20200820@Max: Action in Manage Request did not show information in TVS system [Redmine: #139933]
		- 20200909@Max: HotFix - TVS - Danger Accept - void single when sub parlay process No. of ticket can not show ticket single [Redmine: #141124]

	Param's explanation:	
		@Status: 
			- 0: All
			- 1: New
			- 2: Voided
			- 3: Incompleted
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE	@FilteredBy	TINYINT
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

	DECLARE @VIPAccount_tmp AS TABLE (CustID INT)
	DECLARE  @query NVARCHAR(MAX) = ''
		, @ExecuteSQL NVARCHAR(MAX) = ''

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
		,VoidFromTime	DATETIME
		,VoidToTime		DATETIME
	)
	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

	DECLARE @SubIssueType_tmp TABlE (SubIssueTypeId INT)
	DECLARE @MatchidList_Waiting_30minutes_tmp TABLE (MatchId INT)

	CREATE TABLE #Incompleted_tmp (RequestId INT, StatusId TINYINT)

	IF @IssueTypeId IS NOT NULL AND @SubIssueType IS NOT NULL
	BEGIN
		INSERT INTO @tmpIssueType (IssueTypeId)
		SELECT DISTINCT val
		FROM dbo.f_SplitString(@IssueTypeId, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)

		INSERT INTO @SubIssueType_tmp (SubIssueTypeId)
		SELECT	val AS TransId
		FROM	dbo.f_SplitString(@SubIssueType, ',')
		OPTION (maxrecursion 0) 
	END

	SELECT	@FilteredBy = CASE
								WHEN @RequestId IS NOT NULL THEN 1 -- RequestId
								ELSE
									CASE 
										WHEN @MatchId IS NOT NULL THEN 2 -- MatchId
										ELSE 3 -- Fromdate, Todate
									END
							END

	IF @FilteredBy = 1
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime)
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
				,rd.VoidFromTime
				,rd.VoidToTime
		FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
				SELECT	m.matchid, m.eventdate
				FROM	dbo.match m WITH(NOLOCK)
				UNION ALL
				SELECT	m14.MatchId, m14.eventdate
				FROM	dbo.match14 m14 WITH(NOLOCK)
				) m
				ON rd.MatchId = m.matchid
		WHERE	r.RequestId = @RequestId
					   		
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		INSERT INTO @tmpRequest (RequestId)
		SELECT	DISTINCT rd.RequestId
		FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		WHERE	rd.MatchId = @MatchId

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, VoidFromTime, VoidToTime)
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
				,rd.VoidFromTime
				,rd.VoidToTime
		FROM	@tmpRequest t
			INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK)
				ON t.RequestId = r.RequestId
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
				SELECT	m.matchid, m.eventdate
				FROM	dbo.match m WITH(NOLOCK)
				UNION ALL
				SELECT	m14.MatchId, m14.eventdate
				FROM	dbo.match14 m14 WITH(NOLOCK)
				) m
				ON rd.MatchId = m.matchid
			INNER JOIN @tmpIssueType tmp 
				ON tmp.IssueTypeId = r.IssueTypeId
			INNER JOIN @SubIssueType_tmp sub
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE	(@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds,IssueTypeId, VoidFromTime, VoidToTime)
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
				,rd.VoidFromTime
				,rd.VoidToTime
		FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
				SELECT	m.matchid, m.eventdate
				FROM	dbo.match m WITH(NOLOCK)
				UNION ALL
				SELECT	m14.MatchId, m14.eventdate
				FROM	dbo.match14 m14 WITH(NOLOCK)
				) m
				ON rd.MatchId = m.matchid
			INNER JOIN @tmpIssueType tmp 
				ON tmp.IssueTypeId = r.IssueTypeId
			INNER JOIN @SubIssueType_tmp sub
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE	m.eventdate BETWEEN @FromDate AND @ToDate
			AND ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
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
					--,SUM(CASE WHEN z.bettype NOT BETWEEN 901 AND 920 AND ISNULL(z.comstatus,'') <> 'CO' THEN 1 ELSE 0 END) AS TotalVoidedSingle
					,SUM(CASE 
							WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
							WHEN z.bettype = 911 THEN 1
							ELSE 0 END
						) AS TotalVoidedSingle
					,0 AS TotalVoidedCashOut 
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId
						AND vh.MatchId = z.matchid
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
						AND zm.matchid = vh.MatchId
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
	
	--Incompleted Request	
	IF @Status IN (0,3)
	BEGIN

		INSERT INTO @MatchidList_Waiting_30minutes_tmp (MatchId)
		SELECT DISTINCT matchid
		FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
		WHERE StatusId = 0 AND DATEDIFF(MINUTE, Starttime, GETDATE()) > 30

		SELECT  @query = N''		
		SELECT	@query = @query + N'SELECT Custid 
									FROM dbo.Dep_CustVIP WITH (NOLOCK)	
									'
		SELECT	@ExecuteSQL = N'EXECUTE DBCUST.CUSTDB.dbo.sp_executesql @query'
		INSERT INTO @VIPAccount_tmp(CustID)
		EXECUTE	sys.sp_executesql @ExecuteSQL, N'@query NVARCHAR(MAX)', @query
	
		INSERT INTO #Incompleted_tmp (RequestId, StatusId)
		SELECT RequestId, statusID
		FROM #tmpResult t
			CROSS APPLY (
						SELECT TOP 1 f.val AS transid
							,b.statusID
						FROM dbo.f_SplitString(t.TransIds, ',') f
							CROSS APPLY (
										SELECT TOP 1 CASE WHEN statusID = 112 THEN 1 --Settled Tickets
											WHEN v.CustID IS NOT NULL AND statuswinlost IN (1,2) AND statusID IN (0,1) THEN 3 --VIP Customer Tickets.
											WHEN statuswinlost IN (1,2) AND statusID IN (0,1) THEN 2 --Auto Void Failed
											ELSE 0 END AS statusID
										FROM bettrans b WITH (NOLOCK)
											LEFT JOIN @VIPAccount_tmp v ON v.CustID = b.custid
										WHERE transid = f.val
											AND statusID IN (0,1,112)
									) b
						WHERE statusID IN (1,2,3)
					) AS tmp
		WHERE t.ActionId IN (1,4,5)
		OPTION (maxrecursion 0)		
	END

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
			,CASE WHEN t.IssueTypeId = 11 THEN ts.TotalSingle ELSE 0 END AS TotalSingle
			,CASE WHEN t.IssueTypeId = 11 THEN ts.TransIds ELSE NULL END AS TransIds
			,t.IssueTypeId
			,CASE WHEN (t.TotalSingle = 0 AND t.TotalCashOut = 0 AND t.TotalParlay = 0) AND ic.RequestId IS NULL AND m.MatchId IS NULL THEN 1
				WHEN (t.TotalSingle > 0 OR t.TotalCashOut > 0 OR t.TotalParlay > 0) AND ic.RequestId IS NULL AND m.MatchId IS NULL THEN 2
				WHEN ((ic.RequestId IS NOT NULL AND ic.StatusId = 1) OR (m.MatchId IS NOT NULL AND ic.StatusId = 2) OR ic.StatusId = 3) THEN 3
				ELSE 0 END AS Status
			,CASE WHEN ic.RequestId IS NOT NULL AND ic.StatusId = 1 THEN 'Settled Tickets'
				WHEN m.MatchId IS NOT NULL AND ic.StatusId = 2 THEN 'Auto Void Failed'
				WHEN ic.StatusId = 3 THEN 'VIP Customer Tickets.'
				ELSE NULL END AS IncompletedReason
			,t.VoidFromTime
			,t.VoidToTime
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN CustDB.dbo.Customer ch WITH(NOLOCK)
			ON t.CheckedBy = ch.CustId
		OUTER APPLY (
					SELECT RequestId, StatusId
					FROM #Incompleted_tmp
					WHERE RequestId = t.RequestId
			)ic
		OUTER APPLY (
					SELECT MatchId
					FROM @MatchidList_Waiting_30minutes_tmp
					WHERE MatchId = t.MatchId
			)m
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
	WHERE 1 = CASE 
				WHEN @Status = 0 THEN 1
				WHEN @Status = 1 AND (t.TotalSingle = 0 AND t.TotalCashOut = 0 AND t.TotalParlay = 0) AND ic.RequestId IS NULL AND m.MatchId IS NULL THEN 1
				WHEN @Status = 2 AND (t.TotalSingle > 0 OR t.TotalCashOut > 0 OR t.TotalParlay > 0) AND ic.RequestId IS NULL AND m.MatchId IS NULL THEN 1
				WHEN @Status = 3 AND ((ic.RequestId IS NOT NULL AND ic.StatusId = 1) OR (m.MatchId IS NOT NULL AND ic.StatusId = 2) OR ic.StatusId = 3) THEN 1
				ELSE 0
			END	
	ORDER BY t.RequestId DESC
	
	DROP TABLE #tmpResult
	DROP TABLE #Incompleted_tmp
	
END
