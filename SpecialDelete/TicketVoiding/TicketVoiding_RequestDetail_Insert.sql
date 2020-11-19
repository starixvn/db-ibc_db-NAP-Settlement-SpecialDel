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
		- 20201106@July: [TVS] - Abnormal Account [Redmine: #143666]

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

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT)
	CREATE TABLE #TempMatch (MatchId INT)
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT, Username VARCHAR(30))
	CREATE TABLE #InputValidCustid_tmp (custid INT, Username VARCHAR(30)) 


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
			, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
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
		INSERT INTO #InputUsernameList (Username, custid, roleid)
		SELECT l.val
			  ,ci.custid
			  ,ci.roleid
		FROM  dbo.f_SplitString(@UserNames, ',') l
			LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.val = ci.username
		WHERE val <> '' AND ci.custid IS NOT NULL
		OPTION (MAXRECURSION 0)
	
		INSERT INTO #InputValidCustid_2 (custid,Username)		
		SELECT l.custid,l.Username
		FROM #InputUsernameList l
		WHERE l.roleid = 2

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 3)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid,Username)	
			SELECT ci.custid,l.Username
			FROM #InputUsernameList l
				INNER JOIN custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
			WHERE l.roleid = 3 AND ci.roleid = 2
		END

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid,Username)
			SELECT ci.custid,l.Username
			FROM #InputUsernameList l
				INNER JOIN dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
			WHERE l.roleid = 4 AND ci.roleid = 2	
		END

		-- list of member to process
		INSERT INTO #InputValidCustid_tmp (CustID, Username)
		SELECT  CustID, l.Username
		FROM #InputUsernameList l
		WHERE l.roleid =1
		UNION ALL
		SELECT ci.CustID,lt.Username
		FROM #InputValidCustid_2 lt
			INNER JOIN dbo.custInfo ci WITH (NOLOCK)
			ON lt.custid = ci.recommend
		WHERE ci.roleid = 1
		;
	
		INSERT INTO #TempMatch(matchid)
		SELECT  DISTINCT b.matchid 
		FROM #InputValidCustid_tmp c 
		CROSS APPLY (
						SELECT b.matchid
						FROM dbo.bettrans b WITH(NOLOCK)
						WHERE c.custid = b.custid AND b.matchid <> 0 
					)b

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
		FROM #TempMatch t
			LEFT JOIN dbo.match m WITH(NOLOCK) ON t.MatchId = m.matchid
		
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
																, @MarkType = 1, @LogActionId = 90508
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
																+ ', From Winlost Date: '+ CAST(@FromDate AS VARCHAR(50))
																+ ', To Winlost Date: '+ CASE WHEN @ToDate IS NOT NULL THEN CAST(@ToDate AS VARCHAR(50)) ELSE 'NULL' END
													
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
	
END
GO