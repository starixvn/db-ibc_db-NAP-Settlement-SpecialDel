/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Update]
(
	@RequestId				INT
	,@MatchId				INT = 0
	,@KickOffTime			DATETIME = NULL
	,@UserId				INT
	,@IP					VARCHAR(50) = NULL
	,@TransIds 				VARCHAR(MAX) = NULL
	,@ActionId				TINYINT
	,@IssueTypeId			TINYINT
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
	,@IsCheckedHomeTeam		BIT = 0
	,@IsCheckedAwayTeam		BIT = 0
	,@SubIssueTypeId		TINYINT = NULL
	,@IsConfirmCalculator   BIT = 0
	,@UserNames				VARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50)  = NULL
	,@StatusIds				VARCHAR(50)  = NULL
	,@FromDate				DATETIME     = NULL
    ,@ToDate				DATETIME     = NULL
	,@IsVoidVIPMember		BIT = 0
	,@TypeAccept			VARCHAR(MAX)  = NULL
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
	,@ErrMsg				NVARCHAR(200) = '' OUTPUT
    ,@ErrCode				INT           = 0  OUTPUT
	,@FailedTransIds		VARCHAR(MAX) = NULL	OUTPUT
	,@NegativeBalanceUsers  VARCHAR(MAX) = ''	OUTPUT
)
AS
/*	Created by: Kathy
	Date 20181212
	Task: update request detail [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
		- 20191111@Max: Ticket Voiding System - Abnormal Bet Issue Type [Redmine: #111541]
		- 20191213@Charles: Write log TVS after add abnormal bet issue type [111541]
		- 20200216@Max: Abnormal Void Bets Automation [Redmine: #128359]
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
		- 20210224@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075] 
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210401@July: TVS - Abnormal Bet - Auto void before KO time - [Redmine: #150522]
		- 20210324@Helen: SP Tuning - EC Prepration [Redmine: #151103]
		- 20210402@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210413@Max: [TVS] SP tuning for EC20 - P1 [Redmine: #152817]
		- 20210427@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
	Param's explanation:
		@WrongScoreInfo: 
		<root>
			<r RequestId="" MatchId="" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" LiveHomeScore ="" LiveAwayScore="" LiveScores=""/>
		</root>
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime				 DATETIME
			,@EndTime				 DATETIME
			,@LogActionId			 INT
			,@LogData				 VARCHAR(MAX)
			,@LogDataContent		 VARCHAR(MAX)
			,@SB_Error				 BIT
			,@OldKickOffTime		 DATETIME
			,@LeagueId				 INT = NULL
			,@HomeId				 INT = NULL
			,@AwayId				 INT = NULL
			,@Sporttype				 SMALLINT = NULL
			,@OldMatchId			 INT
			,@OldTransIds 			 VARCHAR(MAX) = NULL
			,@MarkedTransIds		 VARCHAR(MAX)
			,@Username				 NVARCHAR(200)
			,@IsCalQueue			 BIT = 0
			,@IsTransidProcessed	 BIT = 0
			--,@OldFilterFromTransTime DATETIME = NULL
			--,@OldFilterToTransTime	 DATETIME = NULL
			--,@OldFilterFromBetId	 BIGINT = NULL
			--,@OldFilterToBetId		 BIGINT = NULL
			--,@OldFilterBy			 TINYINT = 0
			,@ResettleTransids       VARCHAR(MAX) = '' 
			,@UnmarkTransids		 VARCHAR(MAX) =''
			,@RemoveTransIds		 VARCHAR(MAX) =''
			,@OldUserNames			 VARCHAR(MAX) = NULL
			,@OldFromDate			 DATETIME     = NULL
			,@OldToDate				 DATETIME     = NULL
			,@OldProductIds			 VARCHAR(50)  = NULL
			,@OldStatusIds			 VARCHAR(50)  = NULL
			,@IsLockMatch			 BIT = 0
			,@IsSB					 BIT = 0
			,@IsParlay				 BIT = 0
			,@IsBB					 BIT = 0
			,@IsOutright			 BIT = 0
			,@IsSaba				 BIT = 0
			,@IsNonSport			 BIT = 0
			,@moveBetDay14 			 SMALLDATETIME
			,@moveBetDay 			 SMALLDATETIME
			,@FromWinlostDate        DATETIME
			,@OldIsCheckedHomeTeam	 BIT = 0
			,@OldIsCheckedAwayTeam	 BIT = 0	
			,@OldActualScore		 NVARCHAR(300) = NULL
			,@NewActualScore		 NVARCHAR(300) = NULL
			,@OldTypeAccept			 VARCHAR(MAX) = NULL
			,@WrongScoreInfoXML XML = NULL

	CREATE TABLE #inputTransid (transid BIGINT)
	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, groupid INT, StatusId INT, statuswinlost TINYINT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)

	CREATE TABLE #TempEditMatchID ( MatchID INT, IsOutright BIT, IsFlag BIT) -- 0 Remove, 1 -- Add username -> match
	CREATE TABLE #TempMatch (MatchId INT, IsOutright BIT)
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT, recommend INT)
	CREATE TABLE #InputValidCustid_2 (custid INT PRIMARY KEY)
	CREATE TABLE #InputValidCustid_1 (custid INT PRIMARY KEY )
	--CREATE TABLE #InputValidCustid_tmp (custid INT) 
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT )
	CREATE TABLE #tblGetLogInfo (
			RequestID				INT
		,MatchID				INT
		,FilterFromTransTime	DATETIME 
		,FilterToTransTime		DATETIME 
		,FilterFromBetId		BIGINT 
		,FilterToBetId			BIGINT 
		,FilterBy				TINYINT 
		,SingleCount			INT 
		,MainParlayCount		INT 
		,MinSingleTransId		BIGINT 
		,MaxSingleTransId		BIGINT 
		,MinMainParlayTransId	BIGINT 
		,MaxMainParlayTransId	BIGINT 
		,VoidFromTime			DATETIME 
		,VoidToTime				DATETIME
		,LiveHomeScore			INT
		,LiveAwayScore			INT
		,LiveScores				NVARCHAR(300)
		,IsCheckedHomeTeam		BIT 
		,IsCheckedAwayTeam		BIT 
		,TypeAccept				VARCHAR(MAX)
		)
	CREATE TABLE #tblOldResulDetail (
			  RequestId INT
			, MatchId INT
			, FilterFromTransTime DATETIME
			, FilterToTransTime DATETIME
			, FilterFromBetId BIGINT
			, FilterToBetId BIGINT
			, FilterBy TINYINT
			, LiveHomeScore INT
			, LiveAwayScore INT
			, IssueDetail VARCHAR(MAX)
			, IsCheckedHomeTeam	BIT 
			, IsCheckedAwayTeam	BIT
			, TypeAccept VARCHAR(50)
			)

	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90003
	SET @SB_Error = 0

	-- Check edit request after voided
	IF (EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WHERE RequestId = @RequestId))
	BEGIN
		RETURN;
	END

	IF @IssueTypeId IN (11,15) OR @TransIds IS NOT NULL -- Abnormal Bet
	BEGIN
	
		SELECT	@LeagueId = leagueid
				,@HomeId = homeid
				,@AwayId = awayid
				,@Sporttype = sporttype
		FROM	dbo.match WITH(NOLOCK)
		WHERE	matchid = @MatchId
		
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET	LeagueId = ISNULL(@LeagueId, LeagueId)
				,@OldMatchId = MatchId
				,MatchId = ISNULL(@MatchId, MatchId)
				,HomeId = ISNULL(@HomeId, HomeId)
				,AwayId = ISNULL(@AwayId, AwayId)
				,@OldTransIds = TransIds
				,RequestType = CASE WHEN @IssueTypeId IN (11,15) AND ISNULL(@IsVoidVIPMember,0) = 1 THEN 3 -- Void ticket VIP Member
								    WHEN ISNULL(@IsVoidVIPMember,0) = 0 AND @ActionId IN (4,6,7) THEN 1
								    ELSE 0
								END
		WHERE	RequestId = @RequestId
	END
	ELSE IF @IssueTypeId IN (1,10,3) -- Danger Accept, Red Card, Wrong Score
	BEGIN
		IF @IssueTypeId IN (3)
		BEGIN
			SET @WrongScoreInfoXML = CONVERT(xml, @WrongScoreInfo)
			INSERT INTO #tblGetLogInfo( 
				   RequestID				
				  ,MatchID				
				  ,FilterFromTransTime	
				  ,FilterToTransTime					
				  ,SingleCount			
				  ,MainParlayCount		
				  ,MinSingleTransId		
				  ,MaxSingleTransId		
				  ,MinMainParlayTransId	
				  ,MaxMainParlayTransId	
				  ,VoidFromTime			
				  ,VoidToTime
				  ,LiveHomeScore
				  ,LiveAwayScore				
				)
			SELECT t.c.value('@RequestID','INT') AS RequestId
				  ,t.c.value('@MatchID','INT') AS MatchID
				  ,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
				  ,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
				  ,t.c.value('@SingleCount','INT') AS SingleCount
				  ,t.c.value('@MainParlayCount','INT') AS MainParlayCount
				  ,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
				  ,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
				  ,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
				  ,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
				  ,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
				  ,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
				  ,t.c.value('@LiveHomeScore','INT') AS LiveHomeScore
				  ,t.c.value('@LiveAwayScore','INT') AS LiveAwayScore
			FROM @WrongScoreInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))
		END
		ELSE
		BEGIN
			INSERT INTO #tblGetLogInfo( 
				   RequestID				
				  ,MatchID				
				  ,FilterFromTransTime	
				  ,FilterToTransTime		
				  ,FilterFromBetId		
				  ,FilterToBetId			
				  ,FilterBy				
				  ,SingleCount			
				  ,MainParlayCount		
				  ,MinSingleTransId		
				  ,MaxSingleTransId		
				  ,MinMainParlayTransId	
				  ,MaxMainParlayTransId	
				  ,VoidFromTime			
				  ,VoidToTime				
				  ,LiveScores				
				  ,IsCheckedHomeTeam		
				  ,IsCheckedAwayTeam		
				  ,TypeAccept
				)
			SELECT @RequestId, @MatchId, @FilterFromTransTime, @FilterToTransTime, @FilterFromBetId, @FilterToBetId, @FilterBy, @SingleCount, @MainParlayCount, @MinSingleTransId, @MaxSingleTransId
				, @MinMainParlayTransId, @MaxMainParlayTransId, @VoidFromTime, @VoidToTime, @LiveScores, @IsCheckedHomeTeam, @IsCheckedAwayTeam, @TypeAccept
		END

		INSERT INTO #tblOldResulDetail (RequestId, MatchId , FilterFromTransTime, FilterToTransTime, FilterFromBetId, FilterToBetId, FilterBy, LiveHomeScore, LiveAwayScore, IssueDetail, IsCheckedHomeTeam, IsCheckedAwayTeam, TypeAccept)
		SELECT RequestId
			 , MatchId
			 , FilterFromTransTime
			 , FilterToTransTime
			 , FilterFromBetId
			 , FilterToBetId
			 , FilterBy
			 , LiveHomeScore
			 , LiveAwayScore
			 , IssueDetail
			 , IsCheckedHomeTeam
			 , IsCheckedAwayTeam
			 , TransIds
		FROM dbo.TicketVoiding_RequestDetail  WITH(NOLOCK)
		WHERE RequestId = @RequestId AND MatchId = @MatchId

		UPDATE	r
		SET	  @OldActualScore = r.IssueDetail
			-- @OldFilterFromTransTime = FilterFromTransTime
			--, @OldFilterToTransTime = FilterToTransTime
			--, @OldFilterFromBetId = FilterFromBetId
			--, @OldFilterToBetId = FilterToBetId
			--, @OldFilterBy = FilterBy
			, FilterFromTransTime = l.FilterFromTransTime
			, FilterToTransTime = l.FilterToTransTime
			, FilterFromBetId = l.FilterFromBetId
			, FilterToBetId = l.FilterToBetId
			, FilterBy = l.FilterBy
			, SingleCount = l.SingleCount
			, MainParlayCount = l.MainParlayCount
			, MinSingleTransId = l.MinSingleTransId
			, MaxSingleTransId = l.MaxSingleTransId
			, MinMainParlayTransId = l.MinMainParlayTransId
			, MaxMainParlayTransId = l.MaxMainParlayTransId
			, VoidFromTime = l.VoidFromTime
			, VoidToTime = l.VoidToTime
			, LiveHomeScore = l.LiveHomeScore
			, LiveAwayScore = l.LiveAwayScore
			, IssueDetail = l.LiveScores
			, IsCheckedHomeTeam = l.IsCheckedHomeTeam
			, IsCheckedAwayTeam = l.IsCheckedAwayTeam
			, TransIds = l.TypeAccept
		FROM dbo.TicketVoiding_RequestDetail r WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #tblGetLogInfo l ON l.RequestID = r.RequestId AND l.MatchID = r.MatchId
		WHERE 1 = CASE WHEN @IssueTypeId IN (1,10) THEN 1 
					   WHEN @IssueTypeId = 3 AND r.LiveHomeScore = l.LiveHomeScore AND r.LiveAwayScore = l.LiveAwayScore THEN 1
					   ELSE 0 END
	END
	ELSE IF @IssueTypeId = 13 -- Abnormal Account
	BEGIN
		
		-- Get info match belong to username
		SELECT @moveBetDay14 = MAX(eventdate) 
		FROM dbo.match14 WITH(NOLOCK)
		WHERE sporttype < 99
	
		SELECT @FromWinlostDate	= ISNULL(@FromDate, @moveBetDay14)
			 , @FromWinlostDate 	= CASE WHEN @FromWinlostDate <= @moveBetDay14 THEN DATEADD(d, 1, @moveBetDay14) ELSE @FromWinlostDate END
		
		IF @ToDate IS NULL
		BEGIN
			SELECT @moveBetDay = MAX(eventdate) 
			FROM dbo.match WITH(NOLOCK)
			WHERE sporttype < 99
			
			SET @ToDate = @moveBetDay
		END

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

		INSERT INTO #InputUsernameList (Username, custid, roleid, recommend)
		SELECT l.val
			  ,ci.custid
			  ,ci.roleid
			  ,ci.recommend
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
			SELECT DISTINCT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.mrecommend
				LEFT JOIN #InputValidCustid_2 ag ON ag.custid = ci.custid
			WHERE l.roleid = 3 AND ci.roleid = 2 AND ag.custid IS NULL

		END

		IF EXISTS (SELECT TOP 1 1 FROM #InputUsernameList WHERE roleid = 4)
		BEGIN
			INSERT INTO #InputValidCustid_2 (custid)
			SELECT DISTINCT ci.custid
			FROM #InputUsernameList l
				INNER JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.custid = ci.srecommend
				LEFT JOIN #InputValidCustid_2 ag ON ag.custid = ci.custid
			WHERE l.roleid = 4 AND ci.roleid = 2 AND ag.custid IS NULL
		END

		
		-- list of member to process
		INSERT INTO #InputValidCustid_1 (CustID)
		SELECT  DISTINCT l1.CustID
		FROM #InputUsernameList l1
			LEFT JOIN #InputValidCustid_2 l2 ON l1.recommend = l2.custid 
		WHERE l1.roleid = 1 AND l2.custid IS NULL
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
			AND pt.bettype NOT IN (31,32,33,71,72,73)  -- NOT IN [Racing, Casino]
			AND pt.bettype NOT IN (911, 912, 913, 914) -- Cash-out subticket
			AND pt.bettype NOT BETWEEN 1501 AND 1599 -- NOT IN Keno

		IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_2)
		BEGIN
			INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
			SELECT	b.translogid AS transid
					,b.statusID  
					,b.eventID
					,b.gameID
			FROM	dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
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
				INNER JOIN #InputValidCustid_2 c ON c.CustId = b.recommend
				OUTER APPLY (
					SELECT TOP 1 m.sporttype 
					FROM dbo.match m WITH (NOLOCK)
					WHERE m.matchid = b.matchid
						AND m.sporttype = 50
				)mc
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND 1 = CASE 
							WHEN @IsSB = 1 
								AND b.bettype BETWEEN 801 AND 806 
								AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
							WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
								AND b.bettype NOT BETWEEN 801 AND 806-- MG
								AND ml.LeagueGroupID IS NULL 
								AND mc.sporttype IS NULL --exclude cricket
								THEN 1
							WHEN @IsSaba = 1 
								AND ml.LeagueGroupID IS NOT NULL THEN 1								
						ELSE 0 END	
				AND statusID IN (SELECT statusID FROM @Status_tmp)
		END
		IF EXISTS (SELECT TOP 1 1 FROM #InputValidCustid_1)
		BEGIN
			INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
			SELECT	b.translogid AS transid
					,b.statusID  
					,b.eventID
					,b.gameID
			FROM	dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
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
				OUTER APPLY (
					SELECT TOP 1 m.sporttype 
					FROM dbo.match m WITH (NOLOCK)
					WHERE m.matchid = b.matchid
						AND m.sporttype = 50
				)mc
				INNER JOIN #InputValidCustid_1 c ON c.CustId = b.custid
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND 1 = CASE 
							WHEN @IsSB = 1 
								AND b.bettype BETWEEN 801 AND 806 
								AND b.statusID NOT IN (0, 101, 102, 103) THEN 1 
							WHEN (@IsSB = 1 OR @IsBB = 1 OR @IsOutright = 1 OR @IsParlay = 1 OR @IsNonSport = 1)
								AND b.bettype NOT BETWEEN 801 AND 806-- MG
								AND ml.LeagueGroupID IS NULL 
								AND mc.sporttype IS NULL --exclude cricket
								THEN 1
							WHEN @IsSaba = 1 
								AND ml.LeagueGroupID IS NOT NULL THEN 1								
						ELSE 0 END	
				AND statusID IN (SELECT statusID FROM @Status_tmp)
		END

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
		
		SELECT   @OldUserNames	 = UserNames
				, @OldFromDate	 = FromWinlostDate
				, @OldToDate	 = ToWinlostDate
				, @OldProductIds = ProductIds
				, @OldStatusIds  = TicketStatusIds
		FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK)
		WHERE RequestId = @RequestId 

		INSERT INTO #TempEditMatchID (MatchID, IsOutright, IsFlag)
		SELECT rd.MatchId,0, 0 -- remove match
		FROM  dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE  NOT EXISTS ( SELECT TOP 1 1 FROM #TempMatch m WHERE rd.MatchId = m.MatchID)
			 AND rd.RequestId = @RequestId
		UNION ALL
		SELECT m.MatchId,m.IsOutright, 1  -- add match
		FROM  #TempMatch m
		OUTER APPLY  (
					SELECT rd.MatchId
					FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					WHERE m.MatchID = rd.MatchId AND rd.RequestId = @RequestId
			)tmp
		WHERE tmp.MatchId IS NULL

		IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 0 )
		BEGIN
				DELETE rd
				FROM dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					INNER JOIN #TempEditMatchID e ON  rd.MatchId = e.MatchID
				WHERE rd.RequestId = @RequestId AND e.IsFlag = 0
		END
			IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 0)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, RequestType
				)
				SELECT @RequestId
					, e.MatchID
					, ISNULL(m.leagueid, 0) 
					, ISNULL(m.homeid, 0) 
					, ISNULL(m.awayid, 0) 
					, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				FROM #TempEditMatchID e 
					LEFT JOIN dbo.match m WITH(NOLOCK) ON e.MatchID = m.matchid 
				WHERE e.IsFlag = 1	AND e.IsOutright = 0	
		END  
		ELSE IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1 AND IsOutright = 1)
		BEGIN
				INSERT INTO dbo.TicketVoiding_RequestDetail 
				(
					RequestId
					, MatchId
					, LeagueId
					, HomeId
					, AwayId
					, RequestType
				)
				SELECT @RequestId
					, e.MatchID
					, m.leagueid
					, m.teamid
					, 0
					, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				FROM #TempEditMatchID e 
					INNER JOIN dbo.outright m WITH(NOLOCK) ON e.MatchID = m.orid
				WHERE e.IsFlag = 1	AND e.IsOutright = 1		
		END  
		
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET   UserNames =  @UserNames
				, ProductIds = @ProductIds
				, TicketStatusIds = @StatusIds
				, FromWinlostDate = @FromDate
				, ToWinlostDate = @ToDate
				, RequestType = CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
		WHERE	RequestId = @RequestId

		-- Insert queue for auto void
		IF @ActionId = 4 AND EXISTS (SELECT TOP 1 1 FROM #TempMatch)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			SELECT @RequestId, m.MatchId, 'VoidInstant', 0, 10278938, GETDATE(), '125.227.140.97', @Sporttype
			FROM #TempMatch m
		END
	END
	ELSE IF @IssueTypeId IN (8,9)--EKO, WKO
	BEGIN
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET	@OldKickOffTime = KickOffTime
				,KickOffTime = ISNULL(@KickOffTime, KickOffTime)
		WHERE	RequestId = @RequestId
				AND MatchId = @MatchId
	END
	
	-- Auto mark ticket running for auto void
	IF @IssueTypeId IN (11,15) AND @Sporttype <= 99
	BEGIN
		
		INSERT INTO #TransidInRequest (TransId)
		SELECT tmp.transid
		FROM dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK) 
			INNER JOIN dbo.TicketVoiding_Request req WITH (NOLOCK) ON req.RequestId = rd.RequestId 
			CROSS APPLY (
						SELECT TransId
						FROM dbo.TicketVoiding_RequestDetailTicket_Single WITH (NOLOCK)
						WHERE RequestId = req.RequestId
					) AS tmp
		WHERE rd.MatchId = @MatchId 
			AND req.RequestId <> @RequestId AND req.ActionId <>2

		INSERT INTO #inputTransid (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)
		
		INSERT INTO #transid_tmp (transid, bettype, StatusId,statuswinlost)
		SELECT t.transid, b.bettype, b.statusID, b.statuswinlost
		FROM #inputTransid t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
		WHERE b.statusID IN (0, 1) --if status of ticket is running

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		SET @IsCalQueue = ( SELECT TOP (1) 1
				FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
				WHERE StatusId IN (1,2,4) AND matchid = @MatchId AND RequestId = 0
				)

		--2.4 remove transid from request => unmark ticket
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #inputTransid it WHERE rdt.TransId=it.transid) -- exist vs input
												  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
												  AND EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = rdt.transid)
												  AND rdt.RequestId=@RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		END

		IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE statusid = 0 AND statuswinlost IS NOT NULL)
				SET @IsTransidProcessed = 1

		IF @ActionId <> 2
		BEGIN
			-- mark ticket
			SELECT @MarkedTransIds = STUFF(
				(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
				FROM #transid_tmp tp
				WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
				GROUP BY TransId for XML PATH('')), 1, 1, ''
				)
			IF @MarkedTransIds IS NOT NULL
			BEGIN
				EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
															, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
			END
		END
		ELSE --update take note
		BEGIN
			SELECT @UnmarkTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM #transid_tmp tp
											WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
												  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)
											FOR XML PATH('')
								), 1,1,'')
			--unmark ticket
			IF @UnmarkTransids IS NOT NULL
			BEGIN
				EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @UnmarkTransids, @UserId = @UserId, @Username = @Username, @IP = @IP
																	, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
			END

			SELECT @ResettleTransids = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
												FROM #transid_tmp
												WHERE --IsMixParlay = 0 AND 
													statuswinlost IS NOT NULL
												FOR XML PATH('')
									), 1,1,'')
			--resettle ticket
			IF (@IsConfirmCalculator = 1)
			BEGIN
				EXEC [dbo].[TicketVoiding_ReCalculate_Single_PreUpdate]
							@Matchid = @Matchid	,
							@TransIds = @ResettleTransids,
							@UserId  = @UserId,
							@IP = @IP,
							@FailedTransIds = @FailedTransIds OUTPUT,
							@ErrMsg = @ErrMsg OUTPUT,
							@ErrCode = @ErrCode OUTPUT,
							@NegativeBalanceUsers = @NegativeBalanceUsers OUTPUT
			     
			END
		END
		
		IF @ActionId IN (4,6,7) OR (@ActionID = 1 AND @IsCalQueue = 1 AND @IsTransidProcessed = 1)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			VALUES(@RequestId, @MatchId, CASE WHEN @ActionId = 1 THEN 'AddRequest' 
											  WHEN @ActionId = 4 THEN 'VoidInstant'
											  WHEN @ActionId = 6 THEN 'VoidInstant5m'
											  ELSE 'VoidInstant10m' END -- @ActionId = 7
			, 0, 10278938, GETDATE(), '125.227.140.97', @Sporttype)
		END
	END

	-- Get content of log data
	SET @LogDataContent = ''
	IF @IssueTypeId IN (11,15) OR @TransIds IS NOT NULL
	BEGIN
		IF @MatchId <> @OldMatchId
		BEGIN
			SET @LogDataContent += ' Old MatchId: ' + CAST(@OldMatchId AS VARCHAR(20))
									+ ' New MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', '
		END
		IF @TransIds <> @OldTransIds
		BEGIN
			SET @LogDataContent += ' Old TransIds: ' + @OldTransIds + ' New TransIds: ' + @TransIds
		END
	END
	ELSE IF @IssueTypeId IN (1, 10)
	BEGIN
		--IF @OldFilterBy <> @FilterBy
		--BEGIN
		--	SET @LogDataContent += ' Old FilterBy: ' + CAST(@OldFilterBy AS VARCHAR(10))
		--						+ ' New FilterBy: ' + CAST(@FilterBy AS VARCHAR(10))
		--	IF @FilterBy <> 0 
		--	BEGIN
		--		SET @LogDataContent += ', From: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21) + ', To: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
		--	END
		--	ELSE
		--	BEGIN
		--		SET @LogDataContent += ', From: ' + CAST(@FilterFromBetId AS VARCHAR(20)) + ', To: ' + CAST(@FilterToBetId AS VARCHAR(20))
		--	END

		--END
		--IF @FilterBy <> 0 AND @OldFilterFromTransTime <> @FilterFromTransTime
		--BEGIN
		--	SET @LogDataContent += ' Old From Transdate: ' + CONVERT(VARCHAR(30), @OldFilterFromTransTime, 21)
		--						+ ' New From Transdate: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21)
		--END
		--ELSE IF @FilterBy <> 0 AND @OldFilterToTransTime <> @FilterToTransTime
		--BEGIN
		--	SET @LogDataContent += ' Old To Transdate: ' + CONVERT(VARCHAR(30), @OldFilterToTransTime, 21)
		--						+ ' New To Transdate: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
		--END
		--ELSE IF @FilterBy = 0 AND @OldFilterFromBetId <> @FilterFromBetId
		--BEGIN
		--	SET @LogDataContent += ' Old From BetID: ' + CAST(@OldFilterFromBetId AS VARCHAR(20))
		--							+ ' New From BetID: ' + CAST(@FilterFromBetId AS VARCHAR(20))
		--END
		--ELSE IF @FilterBy = 0 AND @OldFilterToBetId <> @FilterToBetId
		--BEGIN
		--	SET @LogDataContent += ' Old To BetID: ' + CAST(@OldFilterToBetId AS VARCHAR(20))
		--							+ ' New To BetID: ' + CAST(@FilterToBetId AS VARCHAR(20))
		--END
		--IF @IssueTypeId IN (1, 10) AND @SubIssueTypeId IN (1, 2)
		--BEGIN
		--	SET @LogDataContent += 'IsCheckedHomeTeam: '+ CAST(@IsCheckedHomeTeam AS VARCHAR(20)) + ', IsCheckedAwayTeam: ' + CAST(@IsCheckedAwayTeam AS VARCHAR(20))
		--END

		SELECT @LogDataContent +=
				CASE WHEN r.FilterBy <> l.FilterBy AND l.FilterBy <> 0 THEN ' Old FilterBy: ' + CAST(r.FilterBy AS VARCHAR(10)) + ' New FilterBy: ' + CAST(l.FilterBy AS VARCHAR(10)) 
																			+', From: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) + ', To: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
																		ELSE '' END
			   + CASE WHEN l.FilterBy <> 0 AND r.FilterFromTransTime <> l.FilterFromTransTime THEN ' Old From Transdate: ' + CONVERT(VARCHAR(30), r.FilterFromTransTime, 21) + ' New From Transdate: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) 
																		ELSE '' END
			   + CASE WHEN  l.FilterBy <> 0 AND r.FilterToTransTime <> l.FilterToTransTime THEN ' Old To Transdate: ' + CONVERT(VARCHAR(30), r.FilterToTransTime, 21) + ' New To Transdate: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
																		ELSE '' END
			   + CASE WHEN @SubIssueTypeId IN (1,2) AND r.IsCheckedHomeTeam <> l.IsCheckedHomeTeam THEN 'Old IsCheckedHomeTeam: '+ CAST(r.IsCheckedHomeTeam AS VARCHAR(10)) + ', New IsCheckedHomeTeam: ' + CAST(l.IsCheckedHomeTeam AS VARCHAR(10))
																		ELSE '' END
			   + CASE WHEN @SubIssueTypeId IN (1,2) AND r.IsCheckedAwayTeam <> l.IsCheckedAwayTeam THEN 'Old IsCheckedAwayTeam: '+ CAST(r.IsCheckedAwayTeam AS VARCHAR(10)) + ', New IsCheckedAwayTeam: ' + CAST(l.IsCheckedAwayTeam AS VARCHAR(10))
																		ELSE '' END
			   + CASE WHEN @IssueTypeId = 1 AND r.TypeAccept <> l.TypeAccept THEN 'Old TypeAccept: '+ r.TypeAccept + ', New TypeAccept: ' + l.TypeAccept 
																		ELSE '' END
		FROM #tblOldResulDetail r
			INNER JOIN #tblGetLogInfo l ON r.RequestId = l.RequestID AND r.MatchId = l.MatchID

	END
		IF  @SubIssueTypeId IN (1, 2) AND @OldIsCheckedHomeTeam <> @IsCheckedHomeTeam
		BEGIN
			SET @LogDataContent += 'Old IsCheckedHomeTeam: '+ CAST(@OldIsCheckedHomeTeam AS VARCHAR(10)) + ', New IsCheckedHomeTeam: ' + CAST(@IsCheckedHomeTeam AS VARCHAR(10))
		END
		IF  @SubIssueTypeId IN (1, 2) AND @OldIsCheckedAwayTeam <> @IsCheckedAwayTeam
		BEGIN
			SET @LogDataContent += 'Old IsCheckedAwayTeam: '+ CAST(@OldIsCheckedAwayTeam AS VARCHAR(10)) + ', New IsCheckedAwayTeam: ' + CAST(@IsCheckedAwayTeam AS VARCHAR(10))
		END
		IF @OldTypeAccept <> @TypeAccept
		BEGIN
			SET @LogDataContent += 'Old TypeAccept: '+ @OldTypeAccept + ', New TypeAccept: ' + @TypeAccept
		END
	ELSE IF @IssueTypeId = 13
	BEGIN
		IF @OldUserNames <> @UserNames
		BEGIN
			SET @LogDataContent += ' Old Usernames: ' + @OldUserNames + ' New Usernames: ' + @UserNames
		END
		IF @OldProductIds <> @ProductIds
		BEGIN
			SET @LogDataContent += ' Old ProductIds: ' + @OldProductIds + ' New ProductIds: ' + @ProductIds
		END
		IF @OldStatusIds <> @StatusIds
		BEGIN
			SET @LogDataContent += ' Old StatusIds: ' + @OldStatusIds + ' New StatusIds: ' + @StatusIds
		END
		IF @OldFromDate <> @FromDate
		BEGIN
			SET @LogDataContent += ' Old From Date: ' + CONVERT(VARCHAR(10), @OldFromDate, 23) + ' New From Date: ' + CONVERT(VARCHAR(10), @FromDate, 23)
		END
		IF @OldToDate <> @ToDate
		BEGIN
			SET @LogDataContent += ' Old To Date: ' + CONVERT(VARCHAR(10), @OldToDate, 23) + ' New To Date: ' + CONVERT(VARCHAR(10), @ToDate, 23)
		END
		
	END
	ELSE IF @IssueTypeId IN (8,9) OR @KickOffTime IS NOT NULL --EKO,WKO
	BEGIN
		IF @OldKickOffTime <> @KickOffTime
		BEGIN
			SET @LogDataContent += ' Old KickOffTime: ' + CONVERT(VARCHAR(30), @OldKickOffTime, 21)
								+ ' New KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
		END
	END
	ELSE IF @IssueTypeId = 3
	BEGIN

		SELECT @NewActualScore = l.LiveScores
		FROM #tblGetLogInfo l

		SET @LogDataContent += ' Old Actual Score: ' + @OldActualScore + ' New Actual Score: '+ @NewActualScore +', Wrong Score: ' 
		SELECT @LogDataContent += + CAST(l.LiveHomeScore AS VARCHAR(5)) +'-'
								  + CAST(l.LiveAwayScore AS VARCHAR(5))+' ('
								  + CASE WHEN r.FilterFromTransTime <> l.FilterFromTransTime THEN ' Old From Time: ' + CONVERT(VARCHAR(30), r.FilterFromTransTime, 21) + ' New From Time: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21)
																							 ELSE '' END
								  + CASE WHEN r.FilterToTransTime <> l.FilterToTransTime THEN ' Old To Time: ' + CONVERT(VARCHAR(30), r.FilterToTransTime, 21) + ' New To Time: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
																						 ELSE '' END
								  +'); '
								 
		FROM #tblOldResulDetail r
			INNER JOIN #tblGetLogInfo l ON r.RequestId = l.RequestID AND r.MatchId = l.MatchID
		WHERE r.LiveHomeScore = l.LiveHomeScore AND r.LiveAwayScore = l.LiveAwayScore
	END
	/* 9001
	MatchId: 99002244, Actual Score: 2-0, Wrong Score: 1-1 ( From Time: 2021-04-12 04:47:25.263 To Time: 2021-04-12 04:47:25.263); 1-0 ( From Time: 2021-04-12 04:47:25.263 To Time: 2021-04-12 04:47:25.263)
	*/
	/*
	Old Actual Score: 1-0 New Actual Score: 1-1, Wrong Score: 1-1 ( Old From Time: 2021-04-12 04:47:25.263 New From Time: 2021-04-12 04:47:25.263 - Old To Time: 2021-04-12 04:47:25.263 New To Time: 2021-04-12 04:47:25.263)
															; 1-0 ( Old From Time: 2021-04-12 04:47:25.263 New From Time: 2021-04-12 04:47:25.263 - Old To Time: 2021-04-12 04:47:25.263 New To Time: 2021-04-12 04:47:25.263); 
	*/
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' + @LogDataContent
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT

	DROP TABLE #inputTransid
	DROP TABLE #transid_tmp
	DROP TABLE #TransidInRequest
	DROP TABLE #TempEditMatchID
	DROP TABLE #TempMatch
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	--DROP TABLE #InputValidCustid_tmp
	DROP TABLE #transIdTemp
	DROP TABLE #tblGetLogInfo
	DROP TABLE #tblOldResulDetail

END
GO