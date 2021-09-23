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
	,@SubIssueTypeId		TINYINT = NULL
	,@UserNames				NVARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50) = NULL
	,@StatusIds				VARCHAR(50) = NULL
	,@FromDate				DATETIME = NULL
	,@ToDate				DATETIME = NULL
	,@IsVoidVIPMember		BIT = 0
	,@TypeAccept			VARCHAR(MAX) = NULL
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
	,@DangerAcceptedInfo	VARCHAR(MAX) = NULL
	,@RedCardInfo			VARCHAR(MAX) = NULL
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
		- 20210224@July: TVS - Abnormal Bet - Exclude Customer Class - [Redmine: #147176]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075] 
		- 20210304@July: TVS - Abnormal Bet - Auto void before KO time - [Redmine: #150522]
		- 20210318@July: TVS - Danger Accept/Red Card Enhancement - Phase 7 [Redmine: #150459]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210420@July: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210526@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]
		- 20210524@Max: [TVS] Danger Accept Enhancement - Phase 9 [Redmine: #153216]
		- 20210625@Max: [TVS] Wrong Score Enhancement 1 [Redmine: #156349]
		- 20210714@Max: [TVS] Modify the way to get move bet date [Redmine: #154974]
		- 20210802@July: TVS - Red Card Enhancement - Phase 1 [Redmine: #157097]
		- 20210811@Max: [TVS] Wrong Score Enhancement 2 [Redmine: #157096]
		- 20210820@July: TVS - Add new status Void Instant without any policy [Redmine: #160012]

	Param's explanation:
		+ @WrongScoreInfo: 
		<root>
			<r RequestId="" MatchId="" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" LiveHomeScore ="" LiveAwayScore=""/>
		</root>
		+ @DangerAcceptInfo:
			<root>
				<r MatchId="" SubIssueTypeId="1" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" TypeAccept="AA=''0'' SA=''3'' PA=''9'' IsMain=''1''" LiveScores="" FilterBy="1"/>
			</root>
		+ @RedCardInfo:
			<root>
				<r MatchId="" SubIssueTypeId="15" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" TypeAccept="AA=''0'' SA=''3'' PA=''9'' IsMain=''1''" LiveScores="" FilterBy="1"/>
			</root>
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
			,@movebetdate		SMALLDATETIME
			,@maxdate 			DATETIME = '9999-01-01'
			,@FromWinlostDate    DATETIME
			,@LogDataContent	 VARCHAR(MAX)
			,@WrongScoreInfoXML	 XML = NULL
			,@DangerAcceptedInfoXML	XML  = NULL
			,@RedCardInfoXML	 XML = NULL

	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT)
	CREATE TABLE #TempMatch (MatchId INT, IsOutright BIT)
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT )
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)
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
			,TypeAccept				VARCHAR(50)
			,SubIssueTypeId			SMALLINT
			)
	DECLARE @Status_tmp TABLE (StatusId TINYINT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90001
	SET @SB_Error = 0	

	IF @IssueTypeId NOT IN (1,10,3) --DA,RC,WC
	BEGIN
		-- get match info
		SELECT	@LeagueId = leagueid
				,@HomeId = homeid
				,@AwayId = awayid
				,@Sporttype = sporttype
		FROM	dbo.match WITH(NOLOCK)
		WHERE	matchid = @MatchId
	END

	IF @IssueTypeId IN (11,15) --AB,AB(RealMember)
	BEGIN
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
	END
	ELSE IF  @IssueTypeId IN (3) --WC
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
			  ,LiveScores --ActualScore for WC
			  ,SubIssueTypeId
			  ,TypeAccept
			)

		SELECT @RequestId AS RequestId
			  ,@MatchId AS MatchID
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
			  ,t.c.value('@ActualScore','VARCHAR(50)') AS ActualScore
			  ,@SubIssueTypeId
			  ,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" ScoreId="' + t.c.value('@ScoreId','VARCHAR(20)') + '" />' AS TypeAccept
		FROM @WrongScoreInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 1 --Danger Accept
	BEGIN
			SET @DangerAcceptedInfoXML = CONVERT(XML, @DangerAcceptedInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
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
					,TypeAccept
					,SubIssueTypeId
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
					,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
					,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' AS TypeAccept
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @DangerAcceptedInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@DangerAcceptedInfoXML = NULL))
	END
	ELSE IF @IssueTypeId = 10 --Red Card
	BEGIN
			SET @RedCardInfoXML = CONVERT(XML, @RedCardInfo)
			INSERT INTO #tblGetLogInfo( 
					RequestID				
					,MatchID				
					,FilterFromTransTime	
					,FilterToTransTime			
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
					,TypeAccept
					,SubIssueTypeId
				)
			SELECT @RequestId AS RequestId
					,t.c.value('@MatchId','INT') AS MatchID
					,t.c.value('@FilterFromTransTime','DATETIME') AS FilterFromTransTime
					,t.c.value('@FilterToTransTime','DATETIME') AS FilterToTransTime
					,t.c.value('@FilterBy','TINYINT') AS FilterBy
					,t.c.value('@SingleCount','INT') AS SingleCount
					,t.c.value('@MainParlayCount','INT') AS MainParlayCount
					,t.c.value('@MinSingleTransId','BIGINT') AS MinSingleTransId
					,t.c.value('@MaxSingleTransId','BIGINT') AS MaxSingleTransId
					,t.c.value('@MinMainParlayTransId','BIGINT') AS MinMainParlayTransId
					,t.c.value('@MaxMainParlayTransId','BIGINT') AS MaxMainParlayTransId
					,t.c.value('@VoidFromTime','DATETIME') AS VoidFromTime
					,t.c.value('@VoidToTime','DATETIME') AS VoidToTime
					,t.c.value('@LiveScores','VARCHAR(50)') AS LiveScores
					,'<r AA="' + t.c.value('@AATime','VARCHAR(10)') + '" PA="'+ t.c.value('@PATime','VARCHAR(10)') 
						+ '" SA="' + t.c.value('@SATime','VARCHAR(10)') + + '" IsMainMatch="' + t.c.value('@IsMainMatch','VARCHAR(10)') + '" />' 
						AS TypeAccept
					,t.c.value('@SubIssueTypeId','SMALLINT') AS SubIssueTypeId
			FROM @RedCardInfoXML.nodes('root/r') t(c)
			OPTION (OPTIMIZE FOR (@RedCardInfoXML = NULL))
	END
	

	IF @IssueTypeId IN (8,9,11,15) --EKO,WKO,AB,AB(RealMember)
	BEGIN
		INSERT INTO dbo.TicketVoiding_RequestDetail (
			RequestId
			, MatchId
			, LeagueId
			, HomeId
			, AwayId
			, KickOffTime
			, RequestType
			, SubIssueTypeId
		)
		SELECT @RequestId
			, @MatchId
			, @LeagueId
			, @HomeId
			, @AwayId
			, @KickOffTime
			, CASE WHEN @IssueTypeId IN (11,15) AND ISNULL(@IsVoidVIPMember,0) = 1 THEN 3 -- Void ticket VIP Member
				   WHEN ISNULL(@IsVoidVIPMember,0) = 0 AND @ActionId IN (4,6,7,8) THEN 1
				   ELSE 0
				END
			, @SubIssueTypeId
	END
	ELSE IF @IssueTypeId IN (1,10,3) --DA,RC,WC
	BEGIN
		
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
			, LiveHomeScore
			, LiveAwayScore
			, IssueDetail
			, TransIds
			, SubIssueTypeId
			)
		SELECT @RequestId
			, l.MatchID
			, m.leagueid
			, m.homeid
			, m.awayid
			, m.kickofftime
			, 0
			, l.FilterFromTransTime
			, l.FilterToTransTime
			, l.FilterFromBetId
			, l.FilterToBetId
			, l.FilterBy
			, l.SingleCount
			, l.MainParlayCount
			, l.MinSingleTransId
			, l.MaxSingleTransId
			, l.MinMainParlayTransId
			, l.MaxMainParlayTransId
			, l.VoidFromTime
			, l.VoidToTime
			, l.LiveHomeScore
			, l.LiveAwayScore
			, l.LiveScores
			, l.TypeAccept
			, l.SubIssueTypeId
		FROM #tblGetLogInfo l
			INNER JOIN dbo.match m WITH (NOLOCK) ON m.matchid = l.MatchID
	END
	ELSE IF @IssueTypeId = 13 --AC
	BEGIN 
		-- Get info match belong to username
		--Get Movebetdate
		EXEC dbo.NAP_Admin_GetMovebetDate @movebetdate = @movebetdate OUTPUT

		SELECT @FromWinlostDate	= ISNULL(@FromDate, @movebetdate)
				, @FromWinlostDate 	= CASE WHEN @FromWinlostDate <= @movebetdate THEN DATEADD(d, 1, @movebetdate) ELSE @FromWinlostDate END
		
		IF @ToDate IS NULL
		BEGIN
	
			SET @ToDate = @maxdate
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
					AND ISNULL(l.LeagueGroupID,0) IN (42,74,108,113)
			)ml
			OUTER APPLY (
				SELECT TOP 1 m.sporttype 
				FROM dbo.match m WITH (NOLOCK)
				WHERE m.matchid = b.matchid
					AND m.sporttype = 50
			)mc
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
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
				 , SubIssueTypeId
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
				 , @SubIssueTypeId
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
				 , SubIssueTypeId
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
				 , @SubIssueTypeId
			FROM #TempMatch t
				INNER JOIN dbo.outright m WITH(NOLOCK) ON t.MatchId = m.orid
			WHERE t.IsOutright = 1
		END
		
		-- Insert queue for auto void
		IF @ActionId = 4 AND EXISTS (SELECT TOP 1 1 FROM #TempMatch)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			SELECT @RequestId, m.MatchId, 'VoidInstant', 99, 10278938, GETDATE(), '125.227.140.97', @Sporttype
			FROM #TempMatch m
		END
	END
	-- Insert queue for auto void
	IF @IssueTypeId IN (11,15) AND @Sporttype <= 99
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
		
		IF @ActionId IN (4,6,7,8) OR (@ActionID = 1 AND @IsCalQueue = 1 AND @IsTransidProcessed = 1)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			VALUES(@RequestId, @MatchId, CASE WHEN @ActionId = 1 THEN 'AddRequest' 
											  WHEN @ActionId = 4 THEN 'VoidInstant'
											  WHEN @ActionId = 6 THEN 'VoidInstant5m'
											  WHEN @ActionId = 7 THEN 'VoidInstant10m' 
											  WHEN @ActionId = 8 THEN 'VoidInstantNopolicy'
											  ELSE '' END 
			, 99, 10278938, GETDATE(), '125.227.140.97', @Sporttype)
		END
	END
	-- Get content of log data 
	SET @LogDataContent = ''
	IF @IssueTypeId IN (11,15) OR @TransIds IS NOT NULL
	BEGIN
		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', TransIds: ' + @TransIds
	END
	ELSE IF @IssueTypeId IN (1,10)
	BEGIN
		SELECT @LogDataContent += ' MatchId: ' + CAST(l.MatchID AS VARCHAR(20)) 
							   + ', SubIssueTypeId: ' + CAST(l.SubIssueTypeId AS VARCHAR(20))
							   + ', FilterFrom: ' + CONVERT(VARCHAR(30), l.FilterFromTransTime, 21) 
							   + ', FilterTo: ' + CONVERT(VARCHAR(30), l.FilterToTransTime, 21)
							   + ', SingleCount: ' + CAST(l.SingleCount AS VARCHAR(20))
							   + ', MainParlayCount: ' + CAST(l.MainParlayCount AS VARCHAR(20))
							   + ', MinSingleTransId: ' + CAST(l.MinSingleTransId AS VARCHAR(20))
							   + ', MaxSingleTransId: '+ CAST(l.MaxSingleTransId AS VARCHAR(20))
							   + ', MinMainParlayTransId: ' + CAST(l.MinMainParlayTransId AS VARCHAR(20))
					           + ', MaxMainParlayTransId: ' + CAST(l.MaxMainParlayTransId AS VARCHAR(20))
							   + ', VoidFrom: ' + CONVERT(VARCHAR(30), l.VoidFromTime, 21)
							   + ', VoidTo: ' + CONVERT(VARCHAR(30), l.VoidToTime, 21)
							   + ', TypeAccept: ' + l.TypeAccept
								FROM #tblGetLogInfo l
	END
	ELSE IF @IssueTypeId = 13
	BEGIN
		SET @LogDataContent += ' Username: ' + CAST(@UserNames AS VARCHAR(30)) 
							+ ', ProductIds: '+ CAST(@ProductIds AS VARCHAR(50))
							+ ', StatusIds: '+ CAST(@StatusIds AS VARCHAR(50))
							+ ', From Date: '+ CONVERT(VARCHAR(10), @FromDate, 23)
							+ ', To Date: '+ CASE WHEN @ToDate IS NOT NULL THEN CONVERT(VARCHAR(10), @ToDate, 23) ELSE 'NULL' END
	END
	ELSE IF @IssueTypeId IN (8,9) OR @KickOffTime IS NOT NULL
	BEGIN
		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
	END
	ELSE IF @IssueTypeId = 3
	BEGIN
		DECLARE @actualscore varchar(5)

		SELECT @actualscore = l.LiveScores
		FROM #tblGetLogInfo l

		SET @LogDataContent += ' MatchId: ' + CAST(@MatchId AS VARCHAR(20))
								+', SubIssueTypeId: ' + CAST(@SubIssueTypeId AS VARCHAR(20))
								+', Actual Score: ' + @actualscore
								+', Wrong Score: ' 
		SELECT @LogDataContent = @LogDataContent
								+ CAST(l.LiveHomeScore AS VARCHAR(5)) +'-'
								+ CAST(l.LiveAwayScore AS VARCHAR(5))+' ('
								+ 'From Time: '+ CONVERT(VARCHAR(30),l.FilterFromTransTime, 21)  +' - '
								+ 'To Time: '+ CONVERT(VARCHAR(30),l.FilterToTransTime, 21) +'); '
		FROM #tblGetLogInfo l
	END
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
							+ @LogDataContent
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
	DROP TABLE #tblGetLogInfo
	
END
GO