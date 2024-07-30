/*<info serverAlias="DBCTG-bodb02" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestList_Select]
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
/*	Created by: 20181212@Kathy
	Task: view request [Redmine:#90155]
	DB: DBCTG/bodb02
	
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
		- 20210608@July: Search request with Exclude Istest but can still display Request istest = 1 [Redmine: #154988]
		- 20210625@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20211013@Max: [TVS] Danger Accept Enhancement - Phase 10 [Redmine: #155792]
		- 20211101@July: TVS - Abnormal Bet - Void Mix Parlay Ticket [Redmine: #161337]
		- 20211118@July: Change length datatatype [Redmine:#164819]
		- 20211123@July: TVS - Void Archived Tickets [Redmine: #140180]
		- 20211214@July: Remove code CashOut [Redmine: #165097]
		- 20220113@July: TVS - New issue type Wrong HDP and Wrong 1H HDP [Redmine: #146717]
		- 20220225@Max: [TVS] Wrong Score Enhancement 3 [Redmine: #164561]
		- 20220318@July: TVS changes of SQL Server Upgrade to 2019 Phase 4 (dbtrans) [Redmine: #167446]
		- 20220404@Max: [TVS] New issue type Wrong OU & 1H OU [Redmine: #170220]
		- 20220808@July: Change of TVS regarding to Scale out DBTrans [Redmine: #175412]
		- 20221026@July: TVS - VAR message [Redmine: #178088]
		- 20230309@July: [TVS] Enhance voiding flow to reduce the dependence between SiteDB and CentralDB [Redmine: #180625]
		- 20230522@July: Manage Request - Add more columns to the export excel template [Redmine:#188153]
		- 20230717@Max: [TVS] Duplicate Ticket - New Issue Type [Redmine: #187835]
		- 20230908@Max: [TVS] Not Participant issue type [Redmine: #192832]
		- 20231016@Max: [TVS] Add related event for voiding Early Kick Off issue type [Redmine: #188957]
		- 20240102@July: [TVS] Recover Ticket issue type [Redmine: #196020]
		- 20240221@Max: [TVS] Integrate Virtual Sports 4 (Edge Gaming) [Redmine: #200087]
		- 20240307@July: [TVS] Abnormal Bet - Support void System Parlay tickets [Redmine: #196462]
		- 20240319@July: [TVS] SP tuning for EC2024 [Redmine: #200840]
		- 20240416@July: [TVS] Manage Request - Change the export excel template [Redmine: #199925]
		- 20240422@Max: [TVS] Abnormal Bet - Add single tickets of many matches to a request [Redmine: #196027]
		- 20240502@July: [TVS] Abandoned issue type [Redmine: #202626]
		- 20240523@July: [TVS] New issue type Wrong Market Offered & Technical Error [Redmine: #197051/194093]
		- 20240701@July: [TVS] Manage Request - Change way to get data - [Redmine: #205983]
		- 20240718@Max: [TVS] Integrate Virtual Sports 5 (Virtually Sports) [Redmine: #207545]
		- 20240912@Max: [TVS] - Manage request - Missing info Calc Half Time & Calc Full Time When Export Excel [Redmine: #210647]

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

	DECLARE	@FilteredBy				 TINYINT
		   ,@RequestInfoGetCalcTimes VARBINARY(MAX) = NULL
		   ,@RequestInfo			 VARBINARY(MAX) = NULL
		   ,@n						 INT = 2147483647

	CREATE TABLE #tmpRequest (RequestId INT, Eventdate DATETIME)
	DECLARE @tmpMatchVoidingHistory TABLE (
		 RequestId			INT
		,VoidingHistoryId	INT
		,VoidedBy			INT
		,MatchId			INT
		,IssueTypeId		TINYINT
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
		,FilterBy		TINYINT
		,VoidFromTime	DATETIME
		,VoidToTime		DATETIME
		,FromWinlostDate DATETIME
		,ToWinlostDate	DATETIME
		,TotalUserName	INT
		,WrongScores	VARCHAR(MAX)
		,ProductIds		VARCHAR(50)
		,[Provider]	    NVARCHAR(400)
		,Source			NVARCHAR(400)
		,Remark			NVARCHAR(MAX)
		,Trader			VARCHAR(MAX)
		,LA				VARCHAR(MAX)
		,MessageId		INT
		,Message        VARCHAR(MAX)
	)
	CREATE CLUSTERED INDEX CIX_tmpResult_RequestId ON #tmpResult (RequestId)
	DECLARE @tmpIssueType TABLE (IssueTypeId INT)
	DECLARE @tmpSubIssueType TABlE (SubIssueTypeId INT)
	DECLARE @MinEventDate_tmp TABLE (RequestID INT, Eventdate DATETIME)

	INSERT INTO @tmpIssueType (IssueTypeId)
	SELECT DISTINCT value AS IssueTypeId
	FROM STRING_SPLIT(@IssueTypeId, ',')

	INSERT INTO @tmpSubIssueType (SubIssueTypeId)
	SELECT value AS SubIssueTypeId
	FROM STRING_SPLIT(@SubIssueType, ',') 

	SELECT	@FilteredBy = CASE
								WHEN @RequestId IS NOT NULL THEN 1 -- RequestId
								WHEN @MatchId IS NOT NULL THEN 2 -- MatchId
								WHEN @RequestInfoJson IS NOT NULL THEN 3 -- Fromdate, Todate
							END
	-----------------------------GET eventdate of match---------------------------------------------
	IF @FilteredBy = 1
	BEGIN
		IF EXISTS ( SELECT TOP 1 1 FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
					WHERE matchid IN (9, 29, 2799, 10449) AND RequestId = @RequestId
		)
		BEGIN
			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  s.RequestId,MIN(b.winlostdate)
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON s.TransId = b.transid
			WHERE s.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) AND s.RequestId = @RequestId
			GROUP BY s.RequestId

			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  s.RequestId,MIN(b.winlostdate)
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
				INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON s.TransId = b.transid
			WHERE s.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) AND s.RequestId = @RequestId
			GROUP BY s.RequestId
		END

		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT  rd.RequestId, MIN(o.eventdate)
		FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
		CROSS APPLY(
					SELECT o.orid, o.eventdate
					FROM	dbo.outright o WITH(NOLOCK)
					WHERE rd.MatchId = o.orid
					UNION ALL
					SELECT	o14.orid, o14.eventdate
					FROM	dbo.outright14 o14 WITH(NOLOCK)
					WHERE rd.MatchId = o14.orid
					)o 
		WHERE rd.RequestId = @RequestId
		GROUP BY rd.RequestId			   
		
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT rd.RequestId, MIN(m.eventdate)
		FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
		CROSS APPLY (
					SELECT m.matchid, m.eventdate
					FROM	dbo.match m WITH(NOLOCK)
					WHERE rd.MatchId = m.matchid
					UNION ALL
					SELECT	m14.MatchId, m14.eventdate
					FROM	dbo.match14 m14 WITH(NOLOCK)
					WHERE rd.MatchId = m14.matchid
					) m
		WHERE rd.RequestId = @RequestId
		GROUP BY rd.RequestId
	END
	ELSE
	IF @FilteredBy = 2
	BEGIN
		IF @MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
		BEGIN
			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  s.RequestId,MIN(b.winlostdate)
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
				INNER JOIN dbo.bettrans b WITH(NOLOCK) ON s.TransId = b.transid
			WHERE s.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
				AND s.MatchId = @MatchId
			GROUP BY s.RequestId
					
			INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
			SELECT  s.RequestId,MIN(b.winlostdate)
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH(NOLOCK) 
				INNER JOIN dbo.bettrans14 b WITH(NOLOCK) ON s.TransId = b.transid
			WHERE s.matchid IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1))
				AND s.MatchId = @MatchId
			GROUP BY s.RequestId
		END

		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT  rd.RequestId, MIN(o.eventdate)
		FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
		CROSS APPLY(
					SELECT o.orid, o.eventdate
					FROM	dbo.outright o WITH(NOLOCK)
					WHERE rd.MatchId = o.orid
					UNION ALL
					SELECT	o14.orid, o14.eventdate
					FROM	dbo.outright14 o14 WITH(NOLOCK)
					WHERE rd.MatchId = o14.orid
					)o 
		WHERE rd.MatchId = @MatchId
		GROUP BY rd.RequestId
		
		INSERT INTO @MinEventDate_tmp (RequestID, Eventdate)
		SELECT rd.RequestId, MIN(m.eventdate)
		FROM TicketVoiding_RequestDetail rd WITH(NOLOCK)
		CROSS APPLY (
					SELECT m.matchid, m.eventdate
					FROM	dbo.match m WITH(NOLOCK)
					WHERE rd.MatchId = m.matchid
					UNION
					SELECT	m14.MatchId, m14.eventdate
					FROM	dbo.match14 m14 WITH(NOLOCK)
					WHERE rd.MatchId = m14.matchid
					) m
		WHERE rd.MatchId = @MatchId 
		GROUP BY rd.RequestId
		
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpRequest(RequestId, Eventdate)
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
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, ProductIds, Provider, Source, Remark)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN 0 ELSE rd.MatchId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN 0 ELSE rd.Sporttype END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,CASE WHEN m.eventdate IS NULL THEN CAST(GETDATE() AS DATE) ELSE m.eventdate END -- NULL: case AB,AC only ticket parlay in sitedb not repl central
				,CASE WHEN r.IssueTypeId IN (3,19,21,23,12,24) THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,rd.FilterBy
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.ProductIds
				,r.Provider, r.Source, r.Remark
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
						SELECT '|' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE	r.RequestId = @RequestId
					   		
	END
	ELSE IF @FilteredBy = 2
	BEGIN
		INSERT INTO #tmpRequest (RequestId)
		SELECT	DISTINCT rd.RequestId
		FROM	dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
		WHERE	rd.MatchId = @MatchId

		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, ProductIds, Provider, Source, Remark)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN 0 ELSE rd.MatchId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN 0 ELSE rd.Sporttype END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,CASE WHEN m.eventdate IS NULL THEN CAST(GETDATE() AS DATE) ELSE m.eventdate END -- NULL: case AB,AC only ticket parlay in sitedb not repl central
				,CASE WHEN r.IssueTypeId IN (3,19,21,23,12,24) THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,rd.FilterBy
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.ProductIds
				,r.Provider, r.Source, r.Remark
		FROM	#tmpRequest t
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
			INNER JOIN @tmpSubIssueType sub
				ON sub.SubIssueTypeId = rd.SubIssueTypeId
			OUTER APPLY(
						SELECT '|' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE	(@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0
			AND ((r.UserId = @CreatedBy) OR @CreatedBy = 0)
	END
	ELSE IF @FilteredBy = 3
	BEGIN
		INSERT INTO #tmpResult(RequestId, SubIssueTypeId, ActionId, CreatedDate, UserId, MistakenBy, DecidedBy, CheckedBy, MatchId, Sporttype, LeagueId, HomeId, AwayId, KickOffTime, EventDate, TransIds, IssueTypeId, FilterBy, VoidFromTime, VoidToTime, FromWinlostDate, ToWinlostDate, TotalUserName, WrongScores, ProductIds, Provider, Source, Remark)
		SELECT	DISTINCT r.RequestId
				,rd.SubIssueTypeId
				,r.ActionId
				,r.CreatedDate
				,r.UserId
				,r.MistakenBy
				,r.DecidedBy
				,r.CheckedBy
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN 0 ELSE rd.MatchId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) THEN 0 ELSE rd.Sporttype END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.LeagueId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.HomeId END
				,CASE WHEN r.IssueTypeId IN (13,17,22) OR (r.IssueTypeId IN (11,20) AND rd.FilterBy IS NOT NULL) THEN NULL ELSE rd.AwayId END
				,rd.KickOffTime
				,CASE WHEN t.eventdate IS NULL THEN CAST(GETDATE() AS DATE) ELSE t.eventdate END -- NULL: case AB,AC only ticket parlay in sitedb not repl central
				,CASE WHEN r.IssueTypeId IN (3,19,21,23,12,24) THEN NULL ELSE rd.TransIds END
				,r.IssueTypeId
				,rd.FilterBy
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidFromTime ELSE NULL END AS VoidFromTime
				,CASE WHEN r.IssueTypeId <> 3 THEN rd.VoidToTime ELSE NULL END AS VoidToTime
				,rd.FromWinlostDate
				,rd.ToWinlostDate
				,ISNULL((LEN(rd.Usernames)- LEN(REPLACE(rd.Usernames,',','')) + 1),0)
				,CASE WHEN r.IssueTypeId = 3 AND rd.FilterBy = 2 THEN  SUBSTRING(rd.IssueDetail, CHARINDEX('Live:',rd.IssueDetail) + 5, CHARINDEX(';Act:',rd.IssueDetail) - 6)
					ELSE STUFF(w.scores,1,1,'') END AS WrongScores
				,rd.ProductIds
				,r.Provider, r.Source, r.Remark
		FROM #tmpRequest t
			INNER JOIN dbo.TicketVoiding_Request r WITH(NOLOCK)
				ON t.RequestId = r.RequestId
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				ON r.RequestId = rd.RequestId
			INNER JOIN @tmpIssueType tmp 
				ON tmp.IssueTypeId = r.IssueTypeId
			INNER JOIN @tmpSubIssueType sub
				ON sub.SubIssueTypeId = rd.SubIssueTypeId
			OUTER APPLY(
						SELECT '|' + CAST (rd.LiveHomeScore AS VARCHAR(10)) + '-' + CAST (rd.LiveAwayScore AS VARCHAR(10))
						FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
						where r.Requestid = rd.RequestId AND r.IssueTypeId = 3
						FOR XML PATH('')
						)w (scores)
		WHERE ((@IsExcludeTest = 1 AND r.IsTest = 0) OR @IsExcludeTest = 0)
			AND ((r.UserId = @CreatedBy) OR @CreatedBy = 0)
	END

	UPDATE t
	SET t.Trader = o.Trader
	  , t.LA = o.LA
	FROM #tmpResult t 
		CROSS APPLY (
				SELECT STRING_AGG(CASE WHEN o.OperatorTypeId = 1 THEN c.Username ELSE NULL END,', ') AS Trader
					  ,STRING_AGG(CASE WHEN o.OperatorTypeId = 2 THEN c.Username ELSE NULL END,', ') AS LA --Suspender
				FROM dbo.TicketVoiding_OperatorInfo o WITH(NOLOCK)
					INNER JOIN CustDB.dbo.Customer c WITH(NOLOCK) ON o.OperatorId = c.CustId
				WHERE t.RequestId = o.RequestId
			)o

	UPDATE t
	SET t.TransIds = rd.TransIds
	FROM #tmpResult t 
		CROSS APPLY (
				SELECT TOP (1) rd.TransIds
				FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK)
				WHERE t.Requestid = rd.RequestId
			)rd
	WHERE t.IssueTypeId = 3

	INSERT INTO @tmpMatchVoidingHistory (RequestId, VoidingHistoryId, VoidedBy, IssueTypeId, MatchId)
	SELECT DISTINCT	vh.RequestId, vh.VoidingHistoryId, vh.UserId, t.IssueTypeId, t.MatchId
	FROM	#tmpResult t
		CROSS APPLY (
			SELECT vh.RequestId, vh.VoidingHistoryId, vh.UserId
			FROM	dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK)
				INNER JOIN dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					ON vh.VoidingHistoryId = s.VoidingHistoryId 
					AND vh.RequestId = s.requestId
					AND (t.MatchId = s.matchID OR s.matchID = 0 OR t.IssueTypeId IN (13,17,22)) 
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
	
	BEGIN --Get message
		UPDATE t
		SET  t.MessageId = ISNULL(s.MessageId, s.MessageIdSpecial)
		FROM #tmpResult t
			INNER JOIN dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) ON t.RequestId = s.RequestID AND (t.MatchId = s.matchID OR s.matchID = 0)
		
		UPDATE	t 
			SET Message = msg.Content_en
		FROM	#tmpResult t
			INNER JOIN DBMSG.bodb_Message.dbo.[Msg] msg WITH (NOLOCK) ON t.MessageId = msg.MessageId
		WHERE t.MessageId IS NOT NULL
	END

	--- BETS: return all additional information for mailing 
	CREATE TABLE #CTE_CustInfo (CustId INT, UserName VARCHAR(30))
	;WITH CTE_CustIdAll AS (
		SELECT DISTINCT t.custid
		FROM #tmpResult b
		CROSS APPLY (
			VALUES (UserId)
			,(LastVoidedBy)
			,(CheckedBy)
		) AS t (custid)
	)
	INSERT INTO #CTE_CustInfo(custid, username)
	SELECT ci.custid
		 , ci.username
	FROM CustDB.dbo.Customer ci WITH(NOLOCK)
		INNER JOIN CTE_CustIdAll ca ON ci.custid = ca.custid			

	/*****************Return table **************************/
	-- 1. Return infor table
	SELECT   t.RequestId
			,t.SubIssueTypeId
			,CASE WHEN t.MatchId = 0 THEN NULL ELSE t.MatchId END MatchId
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
			,CASE WHEN vh.statusID IS NULL AND s.statusID IS NULL THEN ''
				  ELSE CASE WHEN vh.statusID = 3 OR s.statusID = 3 THEN 'Failed'
							WHEN vh.statusID = 2 AND s.statusID = 2 THEN 'Completed'
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
			,CASE WHEN t.IssueTypeId IN (1,10,3,2,8,9) THEN t.TransIds ELSE NULL END AS RequestExtraInfo
			,CASE WHEN CHARINDEX('1',t.ProductIds) > 0 THEN 'Sportsbook' ELSE NULL END AS Products -- Apply issuetype Recover Ticket
			,m.kickofftime AS KickOffTimeMatch , m.eventdate AS EventDateMatch, m.ParentID AS ParentMatchId, m.matchcode
			,t.Provider, t.Source, t.Remark, t.Trader, t.LA, t.Message
	FROM	#tmpResult t
		LEFT JOIN #CTE_CustInfo c ON t.UserId = c.CustId
		LEFT JOIN #CTE_CustInfo v ON t.LastVoidedBy = v.CustId
		LEFT JOIN #CTE_CustInfo ch ON t.CheckedBy = ch.CustId
		OUTER APPLY (SELECT  SUM(CASE WHEN s.IssueTypeId IN (17) AND s.MatchId NOT IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1
									  WHEN s.IssueTypeId IN (11,20) THEN 1
									  ELSE 0 END) AS TotalSingle
							,SUM(CASE WHEN s.IssueTypeId IN (17) AND s.MatchId IN (SELECT bettype FROM f_TVS_SpeciallyBettypes() WHERE TypeId IN (0,1)) THEN 1 ELSE 0 END) AS TotalParlay
					FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
					WHERE s.RequestId = t.RequestId 
					AND  1 = CASE WHEN t.IssueTypeId IN (17,20) THEN 1
					              WHEN t.IssueTypeId IN (11) AND s.MatchId = t.MatchId THEN 1
								  ELSE 0 END
				)cnt	
		OUTER APPLY ( 
					SELECT TOP 1 vh.StatusId --1: Running | 2: Done | 3: Failed
					FROM dbo.TicketVoiding_VoidingHistory vh WITH(NOLOCK) 
					WHERE vh.RequestId = t.RequestID
					ORDER BY CASE WHEN vh.StatusId = 3 THEN @n ELSE VoidingHistoryId END DESC
				)vh
		OUTER APPLY ( 
					SELECT TOP 1 s.StatusId --1: Running | 2: Done | 3: Failed
					FROM dbo.Ticketvoiding_VoidBetAutomation_Service s WITH(NOLOCK) 
					WHERE s.RequestId = t.RequestID 
					ORDER BY CASE WHEN s.StatusId = 3 THEN @n ELSE VoidingHistoryId END DESC
				)s
		OUTER APPLY (
					SELECT	m.matchcode, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.kickofftime, m.eventdate, m.ParentID
					FROM	dbo.match m WITH(NOLOCK)
					WHERE	m.matchid = t.MatchId
					UNION
					SELECT	m.matchcode, m.hthomescore, m.htawayscore, m.finalhomescore, m.finalawayscore, m.kickofftime, m.eventdate, m.ParentID
					FROM	dbo.match14 m WITH(NOLOCK)
					WHERE	m.matchid = t.matchid
			)m
		OUTER APPLY(
					SELECT CASE WHEN mr.calculate = 1 THEN 'FT: ' + CAST(m.finalhomescore AS VARCHAR(10)) + '-' + CAST(m.finalawayscore AS VARCHAR(10))
								WHEN mr.IsHTCal = 1 THEN 'HT: ' + CAST(m.hthomescore AS VARCHAR(10)) + '-' + CAST(m.htawayscore AS VARCHAR(10))
							ELSE 'HT: _-_' END AS SettlementStatus
					FROM dbo.match_remark mr WITH (NOLOCK) 
					WHERE mr.matchid = t.MatchId
			)mr
	WHERE 1 = CASE 
				--All
				WHEN @Status = -1 THEN 1
				--New
				WHEN @Status = 0 AND vh.statusID IS NULL AND s.statusID IS NULL THEN 1 
				--Completed
				WHEN @Status = 2 AND vh.statusID = 2 AND s.statusID = 2 THEN 1 
				--Failed
				WHEN @Status = 3 AND (vh.statusID = 3 OR s.statusID = 3) THEN 1 
				--Running
				WHEN @Status = 1 AND (vh.statusID = 1 AND s.statusID IS NULL) THEN 1 
				WHEN @Status = 1 AND (s.statusID = 1 AND vh.statusID IS NULL) THEN 1 
				WHEN @Status = 1 AND (vh.statusID = 1 AND s.statusID = 1) THEN 1
				ELSE 0
			END	
	ORDER BY t.RequestId DESC, CASE WHEN t.IssueTypeId IN (1,4,5,6,7) THEN m.matchcode ELSE NULL END
	
	-- 2. Support get total voided ticket
	SET @RequestInfo = COMPRESS((SELECT RequestId AS 'req'
		  ,VoidingHistoryId AS 'vh'
		  ,IssueTypeId AS 'it'
		  ,MatchId AS 'mid'
	FROM @tmpMatchVoidingHistory
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfo, 1) AS RequestInfo

	-- 3. Support get calculate time for Issuetype Abnormal Bet (Single ticket)
	SET @RequestInfoGetCalcTimes = COMPRESS((SELECT RequestId AS 'req'
		  ,Sporttype AS 's'
		  ,MatchId AS 'mid'
		  ,EventDate AS 'e'
	FROM #tmpResult
	WHERE IssueTypeId = 11 AND FilterBy IS NULL 
	FOR JSON PATH))

	SELECT CONVERT(VARCHAR(MAX), @RequestInfoGetCalcTimes, 1) AS RequestInfoGetCalcTimes

	-- 4. Support get bettype name for Issuetype Abnormal Bet (Single ticket)
	SELECT t.RequestId, s.Bettype, s.BetId, t.MatchId
	FROM #tmpResult t
		CROSS APPLY ( 
				SELECT DISTINCT s.Bettype, CASE WHEN f.IsNameXBettype = 1 THEN s.BetId ELSE NULL END AS BetId
				FROM dbo.TicketVoiding_RequestDetailTicket_Single s WITH (NOLOCK)
					LEFT JOIN dbo.f_SD_GetGroupBettypes () f ON f.bettype = s.Bettype
				WHERE s.RequestId = t.RequestId AND s.MatchId = t.MatchId
		)s
	WHERE IssueTypeId = 11 AND FilterBy IS NULL 
	ORDER BY s.Bettype DESC

	DROP TABLE #tmpResult
	DROP TABLE #tmpRequest
	DROP TABLE #CTE_CustInfo
END

