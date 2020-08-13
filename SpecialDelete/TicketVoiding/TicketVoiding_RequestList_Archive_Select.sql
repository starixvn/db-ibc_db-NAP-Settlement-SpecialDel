/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Archive_Select]
(
	@RequestId		INT			    = NULL
	,@MatchId		INT			    = NULL
	,@FromDate		DATETIME	    = NULL
	,@ToDate		DATETIME	    = NULL
	,@IsExcludeTest BIT			    = 1
	,@Status		INT			    = 0
	,@IssueTypeId	VARCHAR(100)	= NULL
	,@SubIssueType  VARCHAR(100)	= NULL
)
AS
/*	Created by: Zane
	Date 20200811
	Task: Edit SP for new change of Archive process [Redmine:#139208]
	DB: DBARC/bodb_Archive
	
	Revisions:		
		- 20200811@Zane: Archive process for Ticket Voiding tables [Redmine:#111093]

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
	)
	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

	DECLARE @SubIssueType_tmp TABlE (SubIssueTypeId INT)
	DECLARE @MatchidList_Waiting_30minutes_tmp TABLE (MatchId INT)

	CREATE TABLE #Incompleted_tmp (RequestId INT, StatusId TINYINT)

	IF @IssueTypeId IS NOT NULL AND @SubIssueType IS NOT NULL
	BEGIN
		INSERT INTO @tmpIssueType (IssueTypeId)
		SELECT DISTINCT val
		FROM bodb02.dbo.f_SplitString(@IssueTypeId, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)

		INSERT INTO @SubIssueType_tmp (SubIssueTypeId)
		SELECT	val AS TransId
		FROM	bodb02.dbo.f_SplitString(@SubIssueType, ',')
		OPTION (maxrecursion 0) 
	END

	SELECT	@FilteredBy = CASE
								WHEN @RequestId IS NOT NULL THEN 1 -- RequestId
								ELSE
									CASE 
										WHEN @MatchId IS NOT NULL THEN 2 -- MatchId & Fromdate, Todate
										ELSE 3 -- Fromdate, Todate
									END
							END

	IF @FilteredBy = 1
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, TransIds, IssueTypeId)
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
				,rd.TransIds
				,r.IssueTypeId
		FROM dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
		WHERE	r.RequestId = @RequestId
					   		
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		INSERT INTO @tmpRequest (RequestId)
		SELECT	DISTINCT rd.RequestId
		FROM	dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
		WHERE	rd.MatchId = @MatchId

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, TransIds, IssueTypeId)
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
				,rd.TransIds
				,r.IssueTypeId
		FROM	@tmpRequest t
			INNER JOIN dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
				ON t.RequestId = r.RequestId
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN @tmpIssueType tmp 
				ON tmp.IssueTypeId = r.IssueTypeId
			INNER JOIN @SubIssueType_tmp sub
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE	r.CreatedDate BETWEEN @FromDate AND @ToDate
				AND ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, TransIds,IssueTypeId)
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
				,rd.TransIds
				,r.IssueTypeId

		FROM	dbo.TicketVoiding_Request_bk r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN @tmpIssueType tmp 
				ON tmp.IssueTypeId = r.IssueTypeId
			INNER JOIN @SubIssueType_tmp sub
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE	r.CreatedDate BETWEEN @FromDate AND @ToDate
			AND ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
	END

	INSERT INTO @tmpMatchVoidingHistory (RequestId, MatchId, VoidingHistoryId, VoidedBy)
	SELECT	vh.RequestId, t.MatchId, vh.VoidingHistoryId, vh.UserId
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
			FROM	dbo.TicketVoiding_VoidingHistory_bk vh WITH(NOLOCK)
			WHERE	vh.RequestId = t.requestId AND vh.StatusId = 2
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
				INNER JOIN dbo.zzzbettrans_bk z WITH(NOLOCK)
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
				INNER JOIN dbo.zzzbettransm_bk zm WITH(NOLOCK)
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
		FROM dbo.TicketVoiding_AutoVoidRequest_Queue_bk WITH (NOLOCK)
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
						FROM bodb02.dbo.f_SplitString(t.TransIds, ',') f
							CROSS APPLY (
										SELECT TOP 1 CASE WHEN statusID = 112 THEN 1 --Settled Tickets
											WHEN v.CustID IS NOT NULL AND statuswinlost IN (1,2) AND statusID IN (0,1) THEN 3 --VIP Customer Tickets.
											WHEN statuswinlost IN (1,2) AND statusID IN (0,1) THEN 2 --Auto Void Failed
											ELSE 0 END AS statusID
										FROM dbo.bettrans_bk b WITH (NOLOCK)
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
			,CASE WHEN t.IssueTypeId = 11 THEN (LEN(t.TransIds) - LEN(REPLACE(t.TransIds, ',', '')) +1) ELSE 0 END AS TotalSingle
			,t.TransIds
			,t.IssueTypeId
			,CASE WHEN (t.TotalSingle = 0 AND t.TotalCashOut = 0 AND t.TotalParlay = 0) AND ic.RequestId IS NULL AND m.MatchId IS NULL THEN 1
				WHEN (t.TotalSingle > 0 OR t.TotalCashOut > 0 OR t.TotalParlay > 0) AND ic.RequestId IS NULL AND m.MatchId IS NULL THEN 2
				WHEN ((ic.RequestId IS NOT NULL AND ic.StatusId = 1) OR (m.MatchId IS NOT NULL AND ic.StatusId = 2) OR ic.StatusId = 3) THEN 3
				ELSE 0 END AS Status
			,CASE WHEN ic.RequestId IS NOT NULL AND ic.StatusId = 1 THEN 'Settled Tickets'
				WHEN m.MatchId IS NOT NULL AND ic.StatusId = 2 THEN 'Auto Void Failed'
				WHEN ic.StatusId = 3 THEN 'VIP Customer Tickets.'
				ELSE NULL END AS IncompletedReason
	FROM	#tmpResult t
		LEFT JOIN DBCUST.CustDB.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN DBCUST.CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN DBCUST.CustDB.dbo.Customer ch WITH(NOLOCK)
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
