/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Select]
(
	@RequestId		INT			= NULL
	,@MatchId		INT			= NULL
	,@FromDate		DATETIME	= NULL
	,@ToDate		DATETIME	= NULL
	,@IsExcludeTest BIT			= 1
	,@Status		INT			= 0
	,@IssueTypeId	TINYINT			= 0
	,@SubIssueType  VARCHAR(100) = NULL
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
		- 20200226@Max: Auto Void Winning Bets - [Redmine: #129184]

	Param's explanation:	
		@Status: 
			- 0: All
			- 1: New
			- 2: Voided
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE	@FilteredBy	TINYINT

	DECLARE @tmpRequest TABLE (RequestId INT)

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
	)

	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

	DECLARE @SubIssueType_tmp TABlE (SubIssueTypeId INT)

	IF @SubIssueType IS NOT NULL
	BEGIN
		INSERT INTO @SubIssueType_tmp (SubIssueTypeId)
		SELECT	val AS TransId
		FROM	dbo.f_SplitString(@SubIssueType, ',')
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
		FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
		WHERE	r.RequestId = @RequestId
					   		
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		INSERT INTO @tmpRequest (RequestId)
		SELECT	DISTINCT rd.RequestId
		FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
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
			INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK)
				ON t.RequestId = r.RequestId
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
		WHERE	r.CreatedDate BETWEEN @FromDate AND @ToDate
				AND ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
				AND ((r.IssueTypeId = @IssueTypeId) OR @IssueTypeId = 0)
				AND 1 = CASE WHEN @IssueTypeId = 0 AND @SubIssueType = 0 THEN 1 
						WHEN r.SubIssueTypeId IN (SELECT SubIssueTypeId FROM @SubIssueType_tmp) THEN 1
					ELSE 0 END
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

		FROM	dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
		WHERE	r.CreatedDate BETWEEN @FromDate AND @ToDate
			AND ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
			AND ((r.IssueTypeId = @IssueTypeId) OR @IssueTypeId = 0)
			AND 1 = CASE WHEN @IssueTypeId = 0 AND @SubIssueType = 0 THEN 1 
						WHEN r.SubIssueTypeId IN (SELECT SubIssueTypeId FROM @SubIssueType_tmp) THEN 1
					ELSE 0 END
	END

	INSERT INTO @tmpMatchVoidingHistory (RequestId, MatchId, VoidingHistoryId, VoidedBy)
	SELECT	vh.RequestId, t.MatchId, vh.VoidingHistoryId, vh.UserId
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
			FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
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
	
	UPDATE t 
		SET EventDate = m.eventdate
	FROM	#tmpResult t
		INNER JOIN (
			SELECT m.matchid, m.eventdate
			FROM	dbo.match m WITH(NOLOCK)
			UNION ALL
			SELECT	m14.MatchId, m14.eventdate
			FROM	dbo.match14 m14 WITH(NOLOCK)
		) m
			ON t.MatchId = m.matchid

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
			,t.TransIds
			,CASE WHEN t.IssueTypeId = 11 THEN (LEN(t.TransIds) - LEN(REPLACE(t.TransIds, ',', '')) +1) ELSE 0 END AS TotalSingle
			,t.IssueTypeId
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN CustDB.dbo.Customer ch WITH(NOLOCK)
			ON t.CheckedBy = ch.CustId
	WHERE 1 = CASE 
				WHEN @Status = 0 THEN 1
				WHEN @Status = 1 AND (t.TotalSingle = 0 AND t.TotalCashOut = 0 AND t.TotalParlay = 0) THEN 1
				WHEN @Status = 2 AND (t.TotalSingle > 0 OR t.TotalCashOut > 0 OR t.TotalParlay > 0) THEN 1
				ELSE 0
			END	
	ORDER BY t.RequestId DESC
	
	DROP TABLE #tmpResult
	
END
