/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Select]
(
	 @RequestIdXml	XML				= NULL
	,@MatchId		INT				= NULL
	,@IsExcludeTest BIT				= 1
	,@Status		INT				= 0
	,@IssueTypeId	VARCHAR(100)	= NULL
	,@SubIssueType  VARCHAR(MAX)	= NULL
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
		- 20210202@July: Modify process for abnormal Account [Redmine:#149776]
		- 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210414@July: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210527@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]

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
		,MatchId			INT
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
		,TotalUserName	INT
		,WrongScores	VARCHAR(MAX)
	)
	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)

	DECLARE @SubIssueType_tmp TABlE (SubIssueTypeId INT)
	DECLARE @MinEventDate_tmp TABLE (RequestID INT, Eventdate DATETIME)
	DECLARE @RequestId_tmp TABlE (RequestId INT)

	INSERT INTO @tmpIssueType (IssueTypeId)
	SELECT DISTINCT val AS IssueTypeId
	FROM dbo.f_SplitString(@IssueTypeId, ',')
	WHERE val <> ''
	OPTION (MAXRECURSION 0)

	INSERT INTO @SubIssueType_tmp (SubIssueTypeId)
	SELECT	val AS SubIssueTypeId
	FROM	dbo.f_SplitString(@SubIssueType, ',')
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
	IF @FilteredBy = 1
	BEGIN
		IF (EXISTS (SELECT TOP 1 1 FROM @tmpIssueType WHERE IssueTypeId = 13))
		BEGIN
			IF EXISTS ( SELECT TOP 1 1 FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
									   WHERE matchid IN (9, 29, 2799) AND RequestId = @RequestId
									   
			)
			BEGIN
					INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
					SELECT  s.RequestId,MIN(b.winlostdate)
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
						INNER JOIN dbo.bettrans b WITH(NOLOCK) ON s.TransId = b.transid
					WHERE s.matchid IN (9, 29, 2799) AND s.RequestId = @RequestId
					GROUP BY s.RequestId

					INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
					SELECT  s.RequestId,MIN(b.winlostdate)
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
						INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON s.TransId = b.transid
					WHERE s.matchid IN (9, 29, 2799) AND s.RequestId = @RequestId
					GROUP BY s.RequestId

			END

			IF EXISTS ( SELECT TOP 1 rd.RequestId, o.eventdate
						FROM TicketVoiding_RequestDetail rd WITH(NOLOCK) 
							INNER JOIN 	(
										 SELECT o.orid, o.eventdate
										 FROM	dbo.outright o WITH(NOLOCK)
										 UNION
										 SELECT	o14.orid, o14.eventdate
										 FROM	dbo.outright14 o14 WITH(NOLOCK)
										)o 
								ON rd.MatchId = o.orid
						WHERE rd.RequestId = @RequestId
						)
			BEGIN
				INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
				SELECT  rd.RequestId, MIN(o.eventdate)
				FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
				INNER JOIN(
							SELECT o.orid, o.eventdate
							FROM	dbo.outright o WITH(NOLOCK)
							UNION ALL
							SELECT	o14.orid, o14.eventdate
							FROM	dbo.outright14 o14 WITH(NOLOCK)
						  )o 
					ON rd.MatchId = o.orid
				WHERE rd.RequestId = @RequestId
				GROUP BY rd.RequestId			   
			END
		END
		
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT rd.RequestId, MIN(m.eventdate)
		FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN (
					SELECT m.matchid, m.eventdate
					FROM	dbo.match m WITH(NOLOCK)
					UNION ALL
					SELECT	m14.MatchId, m14.eventdate
					FROM	dbo.match14 m14 WITH(NOLOCK)
					) m
			ON rd.MatchId = m.matchid
		WHERE rd.RequestId = @RequestId
		GROUP BY rd.RequestId
	END
	ELSE
	IF @FilteredBy = 2
	BEGIN
		IF (EXISTS (SELECT TOP 1 1 FROM @tmpIssueType WHERE IssueTypeId = 13))
		BEGIN
			IF EXISTS ( SELECT TOP 1 1 FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
					   WHERE matchid IN (9, 29, 2799)
					   		AND rd.MatchId = @MatchId
													
			)
			BEGIN
					INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
					SELECT  s.RequestId,MIN(b.winlostdate)
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
						INNER JOIN dbo.bettrans b WITH(NOLOCK) ON s.TransId = b.transid
					WHERE s.matchid IN (9, 29, 2799)
						AND s.MatchId = @MatchId
					GROUP BY s.RequestId
					
					INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
					SELECT  s.RequestId,MIN(b.winlostdate)
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
						INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON s.TransId = b.transid
					WHERE s.matchid IN (9, 29, 2799)
						AND s.MatchId = @MatchId
					GROUP BY s.RequestId

			END

			IF EXISTS ( SELECT TOP 1 rd.RequestId, o.eventdate
						FROM TicketVoiding_RequestDetail rd WITH(NOLOCK) 
							INNER JOIN 	(
										 SELECT o.orid, o.eventdate
										 FROM	dbo.outright o WITH(NOLOCK)
										 UNION
										 SELECT	o14.orid, o14.eventdate
										 FROM	dbo.outright14 o14 WITH(NOLOCK)
										)o 
								ON rd.MatchId = o.orid
						WHERE rd.MatchId = @MatchId
						)
			BEGIN
				INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
				SELECT  rd.RequestId, MIN(o.eventdate)
				FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
				INNER JOIN(
							SELECT o.orid, o.eventdate
							FROM	dbo.outright o WITH(NOLOCK)
							UNION ALL
							SELECT	o14.orid, o14.eventdate
							FROM	dbo.outright14 o14 WITH(NOLOCK)
						  )o 
					ON rd.MatchId = o.orid
			
				WHERE rd.MatchId = @MatchId
				GROUP BY rd.RequestId
			END
		END
		
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT rd.RequestId, MIN(m.eventdate)
		FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
		INNER JOIN (
					SELECT m.matchid, m.eventdate
					FROM	dbo.match m WITH(NOLOCK)
					UNION
					SELECT	m14.MatchId, m14.eventdate
					FROM	dbo.match14 m14 WITH(NOLOCK)
					) m
			ON rd.MatchId = m.matchid
		
		WHERE rd.MatchId = @MatchId 
		GROUP BY rd.RequestId
		
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		IF (EXISTS (SELECT TOP 1 1 FROM @tmpIssueType WHERE IssueTypeId = 13))
		BEGIN
			IF EXISTS ( SELECT TOP 1 1 FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
											INNER JOIN @RequestId_tmp r 
												ON rd.RequestId = r.RequestId 
									   WHERE matchid IN (9, 29, 2799)
									   
			)
			BEGIN
					INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
					SELECT  s.RequestId,MIN(bt.winlostdate)
					FROM @RequestId_tmp r
						INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) ON s.RequestId = r.RequestId
						CROSS APPLY (SELECT winlostdate 
									 FROM dbo.bettrans b WITH(NOLOCK) 
									 WHERE s.TransId = b.transid
									 UNION ALL
									 SELECT winlostdate 
									 FROM dbo.bettrans14 b WITH(NOLOCK) 
									 WHERE s.TransId = b.transid
									 ) AS bt
					WHERE s.matchid IN (9, 29, 2799)
					GROUP BY s.RequestId

			END

			IF EXISTS ( SELECT TOP 1 rd.RequestId, o.eventdate
						FROM TicketVoiding_RequestDetail rd WITH(NOLOCK) 
							INNER JOIN 	(
										 SELECT o.orid, o.eventdate
										 FROM	dbo.outright o WITH(NOLOCK)
										 UNION
										 SELECT	o14.orid, o14.eventdate
										 FROM	dbo.outright14 o14 WITH(NOLOCK)
										)o 
								ON rd.MatchId = o.orid
							INNER JOIN @RequestId_tmp r ON rd.RequestId = r.RequestId
						
						)
			BEGIN
				INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
				SELECT  rd.RequestId, MIN(o.eventdate)
				FROM @RequestId_tmp r
					INNER JOIN TicketVoiding_RequestDetail rd WITH(NOLOCK) ON rd.RequestId = r.RequestId
					INNER JOIN(
								SELECT o.orid, o.eventdate
								FROM	dbo.outright o WITH(NOLOCK)
								UNION
								SELECT	o14.orid, o14.eventdate
								FROM	dbo.outright14 o14 WITH(NOLOCK)
							  )o 
						ON rd.MatchId = o.orid
				GROUP BY rd.RequestId
			END
		END
		
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT rd.RequestId, MIN(m.eventdate)
		FROM @RequestId_tmp r
			INNER JOIN TicketVoiding_RequestDetail rd WITH(NOLOCK) ON rd.RequestId = r.RequestId
			INNER JOIN (
						SELECT m.matchid, m.eventdate
						FROM	dbo.match m WITH(NOLOCK)
						UNION
						SELECT	m14.MatchId, m14.eventdate
						FROM	dbo.match14 m14 WITH(NOLOCK)
						) m
			ON rd.MatchId = m.matchid
		GROUP BY rd.RequestId
	END
	----------------------------- End of EventDate Processing ------------------------------
	IF @FilteredBy = 1
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
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
				,m.eventdate
				,rd.TransIds
				,r.IssueTypeId
				,rd.FilterBy
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,STUFF(w.scores,1,1,'') AS WrongScores
		FROM dbo.TicketVoiding_Request r WITH(NOLOCK)
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN (
						SELECT DISTINCT RequestID, MIN(m.eventdate) eventdate
						FROM @MinEventDate_tmp m
						GROUP BY RequestID
						)m
				ON r.RequestId = m.RequestID
			OUTER APPLY(
						SELECT ',' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE	r.RequestId = @RequestId
					   		
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		INSERT INTO @tmpRequest (RequestId)
		SELECT	DISTINCT rd.RequestId
		FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		WHERE	rd.MatchId = @MatchId

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
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
				,m.eventdate
				,rd.TransIds
				,r.IssueTypeId
				,rd.FilterBy
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,STUFF(w.scores,1,1,'') AS WrongScores
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
				ON sub.SubIssueTypeId = rd.SubIssueTypeId
			OUTER APPLY(
						SELECT ',' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE	(@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
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
				,m.eventdate
				,rd.TransIds
				,r.IssueTypeId
				,rd.FilterBy
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,STUFF(w.scores,1,1,'') AS WrongScores
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
				ON sub.SubIssueTypeId = rd.SubIssueTypeId
			OUTER APPLY(
						SELECT ',' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
	END

	INSERT INTO @tmpMatchVoidingHistory (RequestId, VoidingHistoryId, VoidedBy)
	SELECT DISTINCT	vh.RequestId, vh.VoidingHistoryId, vh.UserId
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
			, MatchId = t.matchid
	FROM @tmpMatchVoidingHistory vh
		INNER JOIN (
			SELECT	vh.VoidingHistoryId
					,SUM(CASE 
							WHEN z.bettype NOT BETWEEN 901 AND 920 THEN 1
							WHEN z.bettype = 911 THEN 1
							ELSE 0 END
						) AS TotalVoidedSingle
					,0 AS TotalVoidedCashOut
					,z.matchid
			FROM @tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettrans z WITH(NOLOCK)
					ON	vh.VoidingHistoryId = z.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId, z.matchid
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
					,zm.matchid
			FROM	@tmpMatchVoidingHistory vh
				INNER JOIN dbo.zzzbettransm zm WITH(NOLOCK)
					ON	zm.VoidingHistoryId = vh.VoidingHistoryId
			GROUP BY vh.VoidingHistoryId, zm.matchid
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
			WHERE	vh.RequestId = t.RequestId AND (vh.MatchId = t.MatchId OR t.MatchId IS NULL)
		) vh

	--Return Data
	SELECT   t.RequestId
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
			,CASE WHEN t.IssueTypeId IN (11,15) THEN LEN(ISNULL(ts.TransIds,'')) - LEN(REPLACE(ISNULL(ts.TransIds,''), ',', ''))  ELSE 0 END AS TotalSingle
			,CASE WHEN t.IssueTypeId IN (11,15) THEN STUFF(ts.TransIds,1,1,'') ELSE NULL END AS TransIds
			,t.IssueTypeId
			,CASE WHEN f.statusID IS NULL AND l.statusID IS NULL THEN ''
				  WHEN ISNULL(f.statusID,l.statusID) IN (1,2) THEN 'Running'
				  WHEN ISNULL(f.statusID,l.statusID) = 12 THEN 'Completed'
				  WHEN ISNULL(f.statusID,l.statusID) = 3 THEN 'Failed'
				  ELSE NULL END AS Status
			,t.FilterBy
			,t.VoidFromTime
			,t.VoidToTime
			,t.FromWinlostDate
			,t.ToWinlostDate
			,t.TotalUserName --no.of accounts
			,t.WrongScores 
	FROM	#tmpResult t
		LEFT JOIN CustDB.dbo.Customer c WITH(NOLOCK)
			ON t.UserId = c.CustId
		LEFT JOIN CustDB.dbo.Customer v WITH(NOLOCK)
			ON t.LastVoidedBy = v.CustId
		LEFT JOIN CustDB.dbo.Customer ch WITH(NOLOCK)
			ON t.CheckedBy = ch.CustId
		
		OUTER APPLY (SELECT ',' + CAST(TransId AS VARCHAR(MAX)) 
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
					WHERE s.RequestId = t.RequestId AND t.IssueTypeId IN (11,15)
					FOR XML PATH('')
				)ts	 (TransIds)
			
		OUTER APPLY ( -- Failed
					SELECT DISTINCT RequestId, 3 AS statusID
					FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					WHERE s.RequestId = t.RequestID
					AND s.statusID IN (3, 13)
					)f
		OUTER APPLY ( -- Completed, Running
					SELECT TOP 1 RequestId, statusID
					FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					WHERE s.RequestId = t.RequestID
					ORDER BY VoidingHistory DESC 
					)l
		OUTER APPLY (
					SELECT	m.matchcode
					FROM	dbo.match m WITH(NOLOCK)
					WHERE	m.matchid = t.MatchId
						AND t.IssueTypeId = 1
					UNION
					SELECT	m.matchcode
					FROM	dbo.match14 m WITH(NOLOCK)
					WHERE	m.matchid = t.matchid
						AND t.IssueTypeId = 1
			)m
	WHERE 1 = CASE 
				WHEN @Status = -1 THEN 1
				WHEN @Status = 0 AND f.statusID IS NULL AND l.statusID IS NULL THEN 1 --New
				WHEN @Status = 1 AND ISNULL(f.statusID,l.statusID) IN (1,2) THEN 1 --Running
				WHEN @Status = 2 AND ISNULL(f.statusID,l.statusID) = 12 THEN 1 -- Completed
				WHEN @Status = 3 AND ISNULL(f.statusID,l.statusID) = 3 THEN 1 -- Failed
				ELSE 0
			END	
	ORDER BY t.RequestId DESC, CASE WHEN t.IssueTypeId = 1 THEN m.matchcode ELSE NULL END
	
	DROP TABLE #tmpResult
	
END

