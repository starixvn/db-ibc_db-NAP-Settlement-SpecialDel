/*<info serverAlias="DBARC-bodb_Archive" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Archive_Select]
(
	 @RequestIdXml	XML				= NULL
	,@MatchId		INT				= NULL
	,@IsExcludeTest BIT				= 1
	,@Status		INT				= 0
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
		- 20201120@Zane: HF - Manage Request [Redmine:#145756]
		- 20201223@July: [TVS] - Abnormal Account [Redmine: #143666]
		- 20210202@July: Modify process for abnormal Account [Redmine:#149776]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]

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

	DECLARE	@FilteredBy			TINYINT,
			@NumberofRequestId	INT,
			@RequestId			INT

	DECLARE @tmpRequest TABLE (RequestId INT)
	DECLARE @tmpIssueType TABLE (IssueTypeId INT)
	DECLARE @tmpMatchVoidingHistory TABLE (
		RequestId			INT
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
		,VoidFromTime	DATETIME
		,VoidToTime		DATETIME
		,FromWinlostDate DATETIME
		,ToWinlostDate	DATETIME
		,TotalUserName	INT
	)
	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

	DECLARE @SubIssueType_tmp TABlE (SubIssueTypeId INT)
	DECLARE @MinEventDate_tmp TABLE (RequestID INT, Eventdate DATETIME)
	DECLARE @RequestId_tmp TABlE (RequestId INT)

	INSERT INTO @tmpIssueType (IssueTypeId)
	SELECT DISTINCT val AS IssueTypeId
	FROM bodb02.dbo.f_SplitString(@IssueTypeId, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	INSERT INTO @SubIssueType_tmp (SubIssueTypeId)
	SELECT	val AS SubIssueTypeId
	FROM	bodb02.dbo.f_SplitString(@SubIssueType, ',')
	OPTION (MAXRECURSION 0) 

	IF @RequestIdXml IS NOT NULL
	BEGIN
		-- Parse xml @RequestId
		INSERT INTO @RequestId_tmp(RequestId)
		SELECT t.c.value('@Id','INT') AS RequestId
		FROM @RequestIdXml.nodes('RequestId') t(c)
		OPTION (OPTIMIZE FOR (@RequestIdXml = NULL))

		SELECT @NumberofRequestId = COUNT(RequestId)
		FROM @RequestId_tmp

		IF @NumberofRequestId = 1
		BEGIN
			SELECT @RequestId = RequestId 
			FROM @RequestId_tmp
		END
	END

	SELECT	@FilteredBy = CASE
								WHEN @RequestIdXml IS NULL THEN 2 -- MatchId
								ELSE
									CASE 
										WHEN @NumberofRequestId = 1 THEN 1 -- RequestId
										ELSE 3 -- Fromdate, Todate
									END
							END
	-----------------------------GET eventdate of match---------------------------------------------
	IF (EXISTS (SELECT TOP 1 1 FROM @tmpIssueType WHERE IssueTypeId = 13))
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM dbo.TicketVoiding_RequestDetail_bk rd WITH(NOLOCK)
										LEFT JOIN @RequestId_tmp r 
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
				LEFT JOIN @RequestId_tmp r 
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
						LEFT JOIN @RequestId_tmp r ON rd.RequestId = r.RequestId 
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
				LEFT JOIN @RequestId_tmp r 
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
		LEFT JOIN @RequestId_tmp r 
			ON rd.RequestId = r.RequestId 
	WHERE 1 = CASE WHEN @FilteredBy = 1 AND rd.RequestId = @RequestId THEN 1 
				   WHEN @FilteredBy = 2 AND rd.MatchId = @MatchId THEN 1
				   WHEN @FilteredBy = 3 AND r.RequestId IS NOT NULL THEN 1
				   ELSE 0 END
	GROUP BY rd.RequestId

	IF @FilteredBy = 1
	BEGIN
	INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName)
		SELECT	DISTINCT r.RequestId
				,r.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,rd.TransIds
				,r.IssueTypeId
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
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

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName)
		SELECT	DISTINCT r.RequestId
				,r.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,rd.TransIds
				,r.IssueTypeId
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
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
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE	(@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, TransIds, IssueTypeId, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName)
		SELECT	DISTINCT r.RequestId
				,r.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.MatchId END
				,r.Sporttype
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId  = 13 THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,rd.TransIds
				,r.IssueTypeId
				,rd.VoidFromTime
				,rd.VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
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
				ON sub.SubIssueTypeId = r.SubIssueTypeId
		WHERE ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
	END

	INSERT INTO @tmpMatchVoidingHistory (RequestId, VoidingHistoryId, VoidedBy)
	SELECT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
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
		
	-- single + cash out ticket	
	UPDATE vh 
		SET TotalSingle =	t.TotalVoidedSingle
			,TotalCashOut = t.TotalVoidedCashOut
	FROM @tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,SUM(CASE 
							WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
							WHEN z.bettype = 911 THEN 1
							ELSE 0 END
						) AS TotalVoidedSingle
					,0 AS TotalVoidedCashOut 
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans_bk z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId
	) t 
		ON	vh.VoidingHistoryId = t.VoidingHistoryId
		
	--parlay
	UPDATE vh
		SET TotalParlay = TotalVoidedParlay
	FROM	@tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,COUNT(1) AS TotalVoidedParlay
			FROM	@tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm_bk zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId
	) t
		ON	vh.VoidingHistoryId = t.VoidingHistoryId

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
			,CASE WHEN t.IssueTypeId IN (11,15) THEN ts.TotalSingle ELSE 0 END AS TotalSingle
			,CASE WHEN t.IssueTypeId IN (11,15) THEN ts.TransIds ELSE NULL END AS TransIds
			,t.IssueTypeId
			,CASE WHEN f.statusID IS NULL AND l.statusID IS NULL THEN ''
				  WHEN ISNULL(f.statusID,l.statusID) IN (1,2) THEN 'Running'
				  WHEN ISNULL(f.statusID,l.statusID) = 12 THEN 'Completed'
				  WHEN ISNULL(f.statusID,l.statusID) = 3 THEN 'Failed'
				  ELSE NULL END AS Status
			,t.VoidFromTime
			,t.VoidToTime
			,t.FromWinlostDate
			,t.ToWinlostDate
			,t.TotalUserName --no.of accounts
	FROM	#tmpResult t
		LEFT JOIN bodb02.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN bodb02.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN bodb02.dbo.Customer ch WITH(NOLOCK)
			ON t.CheckedBy = ch.CustId
		OUTER APPLY (
					SELECT COUNT(1) AS TotalSingle
						,STUFF((
								SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
								FROM TicketVoiding_RequestDetailTicket_Single_bk  WITH (NOLOCK)
								WHERE (RequestId = s.RequestId) 
								FOR XML PATH(''))
								,1,1,''
							) AS TransIds
					FROM dbo.TicketVoiding_RequestDetailTicket_Single_bk s WITH (NOLOCK)
					WHERE s.RequestId = t.RequestId
					GROUP BY s.RequestId
			)ts
		OUTER APPLY ( -- Failed
				SELECT DISTINCT RequestId, 3 AS statusID
				FROM bodb02.dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
				WHERE s.RequestId = t.RequestID
				AND s.statusID IN (3, 13)
				)f
		OUTER APPLY ( -- Completed, Running
					SELECT TOP 1 RequestId, statusID
					FROM bodb02.dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					WHERE s.RequestId = t.RequestID
					ORDER BY VoidingHistory DESC 
					)l

		WHERE 1 = CASE 
				WHEN @Status = -1 THEN 1
				WHEN @Status = 0 AND f.statusID IS NULL AND l.statusID IS NULL THEN 1 --New
				WHEN @Status = 1 AND ISNULL(f.statusID,l.statusID) IN (1,2) THEN 1 --Running
				WHEN @Status = 2 AND ISNULL(f.statusID,l.statusID) = 12 THEN 1 -- Completed
				WHEN @Status = 3 AND ISNULL(f.statusID,l.statusID) = 3 THEN 1 -- Failed
				ELSE 0
			END	
	ORDER BY t.RequestId DESC
	
	DROP TABLE #tmpResult
	
END
