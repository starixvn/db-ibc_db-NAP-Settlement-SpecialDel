/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Insert]
(
	@RequestId				INT
	,@MatchId				INT = 0
	,@IssueTypeId			TINYINT		= NULL
	,@KickOffTime			DATETIME	= NULL
	,@TransIds				VARCHAR(MAX) = NULL
	,@UserId				INT
	,@IP					VARCHAR(50)	= NULL
	,@ActionId				TINYINT
	,@FilterFromTransTime	DATETIME = NULL
	,@FilterToTransTime		DATETIME = NULL
	,@FilterFromBetId		BIGINT = NULL
	,@FilterToBetId			BIGINT = NULL
	,@FilterBy				TINYINT = 1
	,@SingleCount			INT = NULL
	,@MainParlayCount		INT = NULL
	,@MinSingleTransId		BIGINT = NULL
	,@MaxSingleTransId		BIGINT = NULL
	,@MinMainParlayTransId	BIGINT = NULL
	,@MaxMainParlayTransId	BIGINT = NULL
	,@VoidFromTime			DATETIME = NULL
	,@VoidToTime			DATETIME = NULL
	,@LiveScores			NVARCHAR(300) = NULL
	,@IsCheckedHomeTeam		BIT = NULL
	,@IsCheckedAwayTeam		BIT = NULL
	,@SubIssueTypeId		TINYINT = NULL
	,@UserNames				NVARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50) = NULL
	,@StatusIds				VARCHAR(50) = NULL
	,@FromDate				DATETIME = NULL
	,@ToDate				DATETIME = NULL
	,@IsVoidVIPMember		BIT = NULL
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: insert request detail [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191111@Max: Ticket Voiding System - Abnormal Bet Issue Type [Redmine:#111541]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20200213@Charles: Insert queue for auto void [127398]
		- 20200213@Helen: Refactor code [Redmine: #127398]
		- 20200221@Max: HotFix [Redmine: #128924]
		- 20200225@Helen:[TVS] Auto Void winning bet [Redmine:#128836]
		- 20200228@Max: Auto Void Winning Bets [Redmine: #129184]
		- 20200312@Max: Hotfix - Confirm Auto Unmark not work for Early Settlement Bettype - [Redmine: #130279]
		- 20200323@Max: Highlight Abnormal Voiding Request [Redmine: #129639]
		- 20200403@Raymond: Auto void for Tennis [Redmind: #131516]
		- 20200406@Helen:[TVS] Auto Void winning bet  for Tennis + hotfix [Redmine:#131516]
		- 20200518@Max: [TVS] Apply new policy into Void Abnormal Bet rules - [Redmine: #134269]
		- 20200609@Max: [TVS] Auto Void for remaining sports - [Redmine: #135574]
		- 20200701@Max: [TVS] Danger Accept Bets Issue Type [Redmine: #135947]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20200910@Charles: [TVS] Enhance Void by Accept Time [Redmine: #141127]
		- 20200918@Charles: TVS - Enhance for Danger Accept Phase 3 [Redmine: #141579]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201106@July: [TVS] - Abnormal Account + Check lock match before add request [Redmine: #143666]
		- 20210222@July: Hotfix - AC Duplicated customer getting of add request validation [Redmine: #150382]
		- 20210219@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]

	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			 DATETIME
			,@EndTime			 DATETIME
			,@LogActionId		 INT
			,@LogData			 VARCHAR(MAX)
			,@SB_Error			 BIT
			,@LeagueId			 INT
			,@HomeId			 INT
			,@AwayId			 INT
			,@Sporttype 		 SMALLINT
			,@MarkedTransIds	 VARCHAR(MAX)
			,@Username			 NVARCHAR(200)
			,@IsCalQueue		 BIT = 0
			,@IsTransidProcessed BIT = 0
			,@IsLockMatch		 BIT = 0
			,@IsSB				 BIT = 0
			,@IsParlay			 BIT = 0
			,@IsBB				 BIT = 0
			,@IsOutright		 BIT = 0
			,@IsSaba			 BIT = 0
			,@IsNonSport		 BIT = 0
			,@moveBetDay14 		 SMALLDATETIME
			,@moveBetDay 		 SMALLDATETIME
			,@FromWinlostDate    DATETIME	

	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT)
	CREATE TABLE #TempMatch (MatchId INT, IsOutright BIT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT )
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90001
	SET @SB_Error = 0	

	IF @IssueTypeId <> 13 --DA,EKO,WKO,RC,AB
	BEGIN
		-- get match info
		SELECT	@LeagueId = leagueid
				,@HomeId = homeid
				,@AwayId = awayid
				,@Sporttype = sporttype
		FROM	dbo.match WITH(NOLOCK)
		WHERE	matchid = @MatchId

		INSERT INTO #transIdTemp (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)

		INSERT INTO #transid_tmp (transid, bettype,StatusId, statuswinlost)
		SELECT t.transid, b.bettype, b.statusID, b.statuswinlost
		FROM #transIdTemp t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
	
		SET @IsCalQueue = ( SELECT TOP (1) 1
								FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
								WHERE StatusId IN (1,2,4) AND matchid = @MatchId  AND RequestId = 0
								)
	
		IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE statusid = 0 AND statuswinlost IS NOT NULL)
			SET @IsTransidProcessed = 1
		INSERT INTO dbo.TicketVoiding_RequestDetail (
			RequestId
			, MatchId
			, LeagueId
			, HomeId
			, AwayId
			, KickOffTime
			, RequestType
			, FilterFromTransTime
			, FilterToTransTime
			, FilterFromBetId
			, FilterToBetId
			, FilterBy
			, SingleCount
			, MainParlayCount
			, MinSingleTransId
			, MaxSingleTransId
			, MinMainParlayTransId
			, MaxMainParlayTransId
			, VoidFromTime
			, VoidToTime
			, IssueDetail
			, IsCheckedHomeTeam
			, IsCheckedAwayTeam
			)
		SELECT @RequestId
			, @MatchId
			, @LeagueId
			, @HomeId
			, @AwayId
			, @KickOffTime
			, CASE WHEN @ActionId = 4 THEN 1 
					ELSE CASE WHEN @IssueTypeId <> 11 OR (@IssueTypeId = 11 AND @ActionId = 1 AND ISNULL(@IsVoidVIPMember,0) = 0 ) THEN 0
							  WHEN @IssueTypeId = 11 AND @ActionId = 1 AND ISNULL(@IsVoidVIPMember,0) = 1 THEN 3
						 END
				END
			, @FilterFromTransTime
			, @FilterToTransTime
			, @FilterFromBetId
			, @FilterToBetId
			, @FilterBy
			, @SingleCount
			, @MainParlayCount
			, @MinSingleTransId
			, @MaxSingleTransId
			, @MinMainParlayTransId
			, @MaxMainParlayTransId
			, @VoidFromTime
			, @VoidToTime
			, @LiveScores
			, @IsCheckedHomeTeam
			, @IsCheckedAwayTeam
	END
	ELSE --AC
	BEGIN 
		-- Get info match belong to username
			SELECT @moveBetDay14 = MAX(winlostdate) 
		FROM dbo.bettrans14 WITH(NOLOCK)

		SELECT @moveBetDay = MAX(winlostdate) 
		FROM dbo.bettrans WITH(NOLOCK)

		SELECT @FromWinlostDate	= ISNULL(@FromDate, @moveBetDay14)
				, @FromWinlostDate 	= CASE WHEN @FromDate <= @moveBetDay14 THEN DATEADD(d, 1, @moveBetDay14) ELSE @FromDate END
				, @ToDate 		= ISNULL(@ToDate, @moveBetDay)
	
		INSERT INTO @Status_tmp (StatusId)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@StatusIds, ',')
		WHERE val <> ''
		OPTION (MAXRECURSION 0)

		SELECT  @IsSB = CASE WHEN CHARINDEX('1',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsParlay = CASE WHEN CHARINDEX('2',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsBB = CASE WHEN CHARINDEX('3',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsOutright = CASE WHEN CHARINDEX('4',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsSaba = CASE WHEN CHARINDEX('5',@ProductIds) > 0 THEN 1 ELSE 0 END
				, @IsNonSport = CASE WHEN CHARINDEX('6',@ProductIds) > 0 THEN 1 ELSE 0 END

		INSERT INTO #InputUsernameList (Username, custid, roleid)
		SELECT l.val
			  ,ci.custid
			  ,ci.roleid
		FROM  dbo.f_SplitString(@UserNames, ',') l
			LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.val = ci.username
		WHERE val <> '' AND ci.custid IS NOT NULL
		OPTION (MAXRECURSION 0)
	
		INSERT INTO #InputValidCustid_2 (custid)		
		SELECT l.custid
		FROM #InputUsernameList l
		WHERE l.roleid = 2

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 3)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)	
			SELECT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
			WHERE l.roleid = 3 AND ci.roleid = 2
		END

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)
			SELECT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
			WHERE l.roleid = 4 AND ci.roleid = 2	
		END

		-- list of member to process
		INSERT INTO #InputValidCustid_tmp (CustID)
		SELECT  CustID
		FROM #InputUsernameList l
		WHERE l.roleid =1
		UNION
		SELECT ci.CustID
		FROM #InputValidCustid_2 lt
			INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK)
			ON lt.custid = ci.recommend
		WHERE ci.roleid = 1
		;
	
		------------Prepare Data------------------------
		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE 1 = CASE WHEN @UserNames IS NULL THEN 1
					ELSE CASE
							WHEN (@IsSB = 1 OR @IsSaba = 1) 
								AND pt.ProductID = 1 
								AND pt.BetType NOT IN (9,29,10)
								AND pt.SubProduct NOT IN ('Bet Builder') THEN 1 -- Sportsbook
							WHEN @IsOutright = 1 AND pt.bettype IN (10) THEN 1 --Outright
							WHEN @IsParlay = 1 AND pt.bettype IN (9, 29) THEN 1 --parlay, mix-parlay
							WHEN @IsBB = 1 AND pt.SubProduct IN ('Bet Builder') THEN 1 --Bet Builder
							WHEN @IsNonSport = 1 AND ProductID IN (3,5,27) AND pt.SportType NOT IN (168) THEN 1
						ELSE 0 END
				END
			AND pt.SubProduct NOT IN ('BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet trade (BT-)
			AND pt.bettype NOT IN (31,32,33,71,72,73)	-- NOT IN [Racing, Casino]
			AND pt.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
			AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno


		INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
		SELECT	b.translogid AS transid
				,b.statusID  -- add new
				,b.eventID
				,b.gameID
		FROM	dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
		WHERE	b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND b.GameID BETWEEN 801 AND 806
				AND b.statusID = 0
				AND @IsSB = 1
				
		UNION ALL
		SELECT CASE WHEN b.bettype BETWEEN 801 AND 806 THEN b.refno ELSE b.transid END
				,b.statusID
				,b.matchid
				,b.bettype
		FROM dbo.bettrans AS b WITH (NOLOCK)
			OUTER APPLY (
				SELECT TOP 1 1 LeagueGroupID 
				FROM dbo.match m WITH (NOLOCK)
					INNER JOIN dbo.League l WITH (NOLOCK) ON l.leagueid = m.leagueid
				WHERE m.matchid = b.matchid
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108)
			)ml
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
			AND 1 = CASE 
						WHEN @IsSB = 1 
							AND b.bettype BETWEEN 801 AND 806 
							AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
						WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
							AND b.bettype NOT BETWEEN 801 AND 806-- MG
							AND  ml.LeagueGroupID IS NULL THEN 1
						WHEN @IsSaba = 1 
							AND ml.LeagueGroupID IS NOT NULL THEN 1								
					ELSE 0 END	
			AND statusID IN (SELECT statusID FROM @Status_tmp)
		
		IF @ActionId NOT IN (2)
		BEGIN
			INSERT INTO #TransidInRequest (TransId)
			SELECT DISTINCT rs.TransId
			FROM  dbo.TicketVoiding_Request r WITH (NOLOCK) 
				INNER JOIN dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
							ON rs.RequestId = r.RequestId
				CROSS APPLY (
							SELECT TOP 1 t.MatchId, t.transid
							FROM #transIdTemp t
							WHERE t.MatchId = rs.MatchId 
								AND rs.TransId = t.transid
					)t
			WHERE r.RequestId <> @RequestId AND r.ActionId NOT IN (2)

			DELETE 
			FROM #transIdTemp
			WHERE transid IN ( SELECT transid FROM #TransidInRequest) 
		END

		INSERT INTO #TempMatch(MatchId, IsOutright)
		SELECT  DISTINCT matchid,
				CASE WHEN bettype <> 10 THEN 0 
					 WHEN bettype = 10 THEN 1 
					 ELSE NULL END
		FROM #transIdTemp

	   IF EXISTS ( SELECT TOP 1 1 FROM  #TempMatch WHERE IsOutright = 0)
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
				   RequestId
				 , MatchId
				 , LeagueId
				 , HomeId
				 , AwayId
				 , RequestType
				 , Usernames
				 , ProductIds
				 , TicketStatusIds
				 , FromWinlostDate
				 , ToWinlostDate
				 , FilterBy 
			)
			SELECT @RequestId
				 , t.MatchId 
				 , ISNULL(m.leagueid, 0) 
				 , ISNULL(m.homeid, 0) 
				 , ISNULL(m.awayid, 0) 
				 , CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				 , @UserNames
				 , @ProductIds
				 , @StatusIds
				 , @FromDate
				 , @ToDate
				 , @FilterBy
			FROM #TempMatch t
				LEFT JOIN dbo.match m WITH(NOLOCK) ON t.MatchId = m.matchid
			WHERE t.IsOutright = 0

		END
		IF EXISTS (SELECT TOP 1 1 FROM #TempMatch WHERE IsOutright = 1) -- outright
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetail (
				   RequestId
				 , MatchId
				 , LeagueId
				 , HomeId
				 , AwayId
				 , RequestType
				 , Usernames
				 , ProductIds
				 , TicketStatusIds
				 , FromWinlostDate
				 , ToWinlostDate
				 , FilterBy 
			)
			SELECT @RequestId
				 , t.MatchId 
				 , ISNULL(m.leagueid, 0) 
				 , ISNULL(m.teamid, 0) 
				 , 0
				 , CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				 , @UserNames
				 , @ProductIds
				 , @StatusIds
				 , @FromDate
				 , @ToDate
				 , @FilterBy
			FROM #TempMatch t
				INNER JOIN dbo.outright m WITH(NOLOCK) ON t.MatchId = m.orid
			WHERE t.IsOutright = 1
		END
		
		-- Insert queue for auto void
		IF @ActionId = 4 AND EXISTS (SELECT TOP 1 1 FROM #TempMatch)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			SELECT @RequestId, m.MatchId, 'VoidInstant', 0, 10278938, GETDATE(), '125.227.140.97', @Sporttype
			FROM #TempMatch m
		END
	END
	-- Insert queue for auto void
	IF @IssueTypeId = 11 AND @Sporttype <= 99
	BEGIN
		-- mark ticket and not take note
		IF @ActionId <>2
		BEGIN
			-- mark ticket
			SELECT @MarkedTransIds = STUFF(
				(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
				FROM #transid_tmp tp
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
					AND  tp.StatusId IN (0, 1) 
				GROUP BY TransId for XML PATH('')), 1, 1, ''
				)
		
			IF @MarkedTransIds IS NOT NULL
			BEGIN
				SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
				EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
			END		
		END
		
		IF @ActionId = 4 OR (@ActionId = 1 AND @IsCalQueue = 1 AND @IsTransidProcessed = 1)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			VALUES(@RequestId, CAST (@MatchId AS INT), CASE WHEN @ActionId = 1 THEN 'AddRequest' ELSE 'VoidInstant' END, 0, 10278938, GETDATE(), '125.227.140.97', @Sporttype)
		END
	END
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+  (CASE
									WHEN @KickOffTime IS NOT NULL THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
									WHEN @TransIds IS NOT NULL THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', TransIds: ' + @TransIds
									WHEN @IssueTypeId IN (1, 10) AND @SubIssueTypeId NOT IN (1,2) AND  @FilterBy IN(1,2) THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', From: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21) + ', To: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
									WHEN @IssueTypeId IN (1, 10) AND @SubIssueTypeId IN (1,2) AND  @FilterBy IN (1,2) THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', From: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21) + ', To: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
										+ ',IsCheckedHomeTeam: '+ CAST(@IsCheckedHomeTeam AS VARCHAR(20)) + ', IsCheckedAwayTeam: ' + CAST(@IsCheckedAwayTeam AS VARCHAR(20))
									WHEN @IssueTypeId IN (1, 10) AND @SubIssueTypeId NOT IN (1,2) AND  @FilterBy = 0 THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', From: ' + CAST(@FilterFromBetId AS VARCHAR(20)) + ', To: ' + CAST(@FilterToBetId AS VARCHAR(20))
									WHEN @IssueTypeId IN (1, 10) AND @SubIssueTypeId IN (1,2) AND  @FilterBy = 0 THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', From: ' + CAST(@FilterFromBetId AS VARCHAR(20)) + ', To: ' + CAST(@FilterToBetId AS VARCHAR(20))
										+ ',IsCheckedHomeTeam: '+ CAST(@IsCheckedHomeTeam AS VARCHAR(20)) + ', IsCheckedAwayTeam: ' + CAST(@IsCheckedAwayTeam AS VARCHAR(20))
									-- IssueTypeId = 13
									WHEN @IssueTypeId = 13 THEN ' Username: ' + CAST(@UserNames AS VARCHAR(30)) 
																+ ', ProductIds: '+ CAST(@ProductIds AS VARCHAR(50))
																+ ', StatusIds: '+ CAST(@StatusIds AS VARCHAR(50))
																+ ', From Date: '+ CONVERT(VARCHAR(10), @FromDate, 23)
																+ ', To Date: '+ CASE WHEN @ToDate IS NOT NULL THEN CONVERT(VARCHAR(10), @ToDate, 23) ELSE 'NULL' END
													
									ELSE ''
								END)
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #transIdTemp
	DROP TABLE #transid_tmp
	DROP TABLE #TempMatch
	DROP TABLE #InputValidCustid_tmp
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #TransidInRequest
	
END
GO