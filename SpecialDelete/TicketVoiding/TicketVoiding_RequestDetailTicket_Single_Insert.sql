/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetailTicket_Single_Insert]
(	 
	@RequestId				INT
	,@MatchId				INT		= 0
	,@KickOffTime			DATETIME = NULL
	,@IssueTypeId			INT
	,@SubIssueTypeId		INT = NULL
	,@MinSingleTransId		BIGINT = NULL
	,@MaxSingleTransId		BIGINT = NULL
	,@TransIds				VARCHAR(MAX) = NULL
	,@IsEditRequest			BIT = 0
	,@UserId				INT = NULL
	,@IP					VARCHAR(50) = NULL
	,@ActionId				TINYINT = 0
	,@FilterFromTransTime	DATETIME = NULL
	,@FilterToTransTime		DATETIME = NULL
	,@FilterBy				TINYINT = 1
	,@UserNames				VARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50)  = NULL
	,@StatusIds				VARCHAR(50)  = NULL
	,@FromDate				DATETIME     = NULL
    ,@ToDate				DATETIME     = NULL
	,@WrongScoreInfo		VARCHAR(MAX) = NULL
)
AS
/*	
	Created by: Max
	Date 20200701
	Task: [TVS] Danger Accept Bets Issue Type [Redmine: #111573]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20200701@Max: Create new SP [Redmine: #135947]
		- 20200901@July: [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
		- 20201002@Max: [TVS] - Modify bet type list on Home/Away Team filter of Danger Accept [Redmine: #142883]
		- 20201013@July: [TVS] - HotFix - Danger accept add by accept time can add ticket super live [Redmine: #143308]
		- 20201021@July: [TVS] - Wrong Red Card [Redmine: #140951]
		- 20201106@July: [TVS] - Abnormal Account + Check lock match before add request [Redmine: #143666]
		- 20210201@Max: Hotfix - TVS - Abnormal Accounts [Redmine: #149697]
		- 20210222@July: Hotfix - AC Duplicated customer getting of add request validation [Redmine: #150382]
		- 20210302@July: TVS - Integrate Cricket AIO - [Redmine: #150075]
		- 20210329@Max: TVS - Correct Ticket on DBTP [Redmine: #151954]
		- 20210408@July: TVS - New Issue Type - AB (Real Member)- [Redmine: #147175]
		- 20210413@Max: [TVS] SP tuning for EC20 - P1 [Redmine: #152817]
		- 20210427@Max: TVS - New Issue Type - Wrong Score - [Redmine: #140953]
		- 20210524@Max: [TVS] Wrong Score - Void 2H tickets in range time [Redmine: #155598]
		- 20210525@July: [TVS] Exclude PinGoal from Auto Void Winning process [Redmine: #155374]
		- 20210526@July: TVS - Danger Accept Enhancement - Phase 8 [Redmine: #152051]

	Param's explanation:
		(+) @FilterBy:	0 - by BetID
						1 - by Trans time
				 		2 - by Accepted time
		(+) @Products : 1 - Sportbook
						2 - Parlay
						3 - Bet Builder
						4 - Outright
						5 - Saba
						6 - NonSport
		(+) @StatusIds : All, Running, Won, Lose, Draw
		@WrongScoreInfo: 
		<root>
			<r RequestId="" MatchId="" FilterFromTransTime="1" FilterToTransTime ="2" SingleCount="5" MainParlayCount="1" MinSingleTransId="" MaxMainParlayTransId="" VoidFromTime="" VoidToTime="" LiveHomeScore ="" LiveAwayScore="" LiveScores=""/>
		</root>
		
*/
BEGIN
	SET NOCOUNT ON 

	DECLARE @UnMarkedTransIds	  VARCHAR(MAX) = NULL
			,@UserName		      VARCHAR(100) = NULL
			,@MarkedTransIds	  VARCHAR(MAX) = NULL
			,@RemoveTransIds	  VARCHAR(MAX) = ''
			,@moveBetDay14 		  SMALLDATETIME
			,@moveBetDay 		  SMALLDATETIME
			,@IsSB				  BIT = 0
			,@IsParlay			  BIT = 0
			,@IsBB				  BIT = 0
			,@IsOutright		  BIT = 0
			,@IsSaba			  BIT = 0
			,@IsNonSport		  BIT = 0
			,@IsLockMatch		  BIT = 0 -- 0: nolock, 1: lock match
			,@FromWinlostDate     DATETIME
			,@RequestDetailId_DA  INT
			,@WrongScoreInfoXML XML = NULL

	CREATE TABLE #SpecialDeleteBets (
			GroupID               BIGINT,
			transid               BIGINT,
			SubTransid            BIGINT,
			refno                 BIGINT,
			custid                INT,
			username              VARCHAR(30),
			odds                  MONEY,
			SubOdds               MONEY,
			oddsspread            MONEY,
			OddsType              INT,
			transdate             DATETIME,
			bettype               SMALLINT,
			OriginalBetType       SMALLINT,
			betteam               NVARCHAR(10),
			SubBetTeam            NVARCHAR(10),
			betcheck              NVARCHAR(50),
			SubBetcheck           NVARCHAR(50),
			Subhdp1               SMALLMONEY,
			Subhdp2               SMALLMONEY,
			hdp1                  SMALLMONEY,
			hdp2                  SMALLMONEY,
			livehomescore         SMALLINT,
			liveawayscore         SMALLINT,
			creator               INT,
			creatorName           VARCHAR(30),
			Stake                 MONEY,
			currencyname          VARCHAR(20),
			IsDeposit             BIT DEFAULT(0),
			STATUS                NVARCHAR(10),
			SubStatus             NVARCHAR(10),
			srecommend            INT,
			mrecommend            INT,
			recommend             INT,
			SubLeagueId           INT,
			betid                 BIGINT DEFAULT(0),
			Transdesc             NVARCHAR(1000),
			betdaqid              BIGINT,
			ParlayType            SMALLINT DEFAULT(0)
			, -- sub bettype of parlay 
			IsMixParlay           BIT DEFAULT(0),
			SoldId                BIGINT,
			sporttype             SMALLINT,
			modds                 MONEY,
			ExtraInfo             VARCHAR(1000),
			IsCashOutMemberTicket BIT DEFAULT 0,
			MainCashoutId         BIGINT,
			matchid               INT,
			WalletType            TINYINT,
			RefCode               BIGINT,
			BonusID               INT,
			MainTransId           BIGINT,
			WinLost               MONEY,
			IsMarked              BIT,
			LiveIndicator		  BIT
	)

	CREATE TABLE #tmpRefCodeSummary (
			RefCode  BIGINT,
			custid   INT,
			matchid	 INT,
			bettype  SMALLINT,
			transid  BIGINT,
			IsMarked BIT
	)

	CREATE TABLE #tblSoldTicket (transid BIGINT PRIMARY KEY)

	CREATE TABLE #DangerAccept_SingleTickets (TransId BIGINT, StatusId INT, MatchId INT, isFinish BIT, LiveHomeScore SMALLINT, LiveAwayScore SMALLINT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)

	DECLARE @tmpTransIDBatch TABLE (TransId	BIGINT, StatusId INT)
	DECLARE @bettype_tmp AS TABLE (bettype SMALLINT, ProductID TINYINT)
	DECLARE @Status_tmp TABLE (StatusId TINYINT)

	CREATE INDEX IX_SpecialDeleteBets_RefCode ON #SpecialDeleteBets(RefCode)
	CREATE INDEX IX_tmpRefCodeSummary_Refcode ON #tmpRefCodeSummary (RefCode)

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY,StatusId INT, MatchId INT, bettype SMALLINT, isFinish BIT)
	CREATE TABLE #InputUsernameList ( Username VARCHAR(30),custid INT, roleid TINYINT)
	CREATE TABLE #InputValidCustid_2 (custid INT)
	CREATE TABLE #InputValidCustid_tmp (custid INT)
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
			)

	-- Check edit request after voided
	IF (EXISTS (SELECT TOP 1 1 FROM dbo.TicketVoiding_VoidingHistory WHERE RequestId = @RequestId))
	BEGIN
		RETURN;
	END

	IF @IssueTypeId IN (1, 10)
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
		WHERE rd.MatchId = @MatchId AND req.RequestId <> @RequestId AND req.ActionId <>2

		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

		INSERT INTO #DangerAccept_SingleTickets (TransId, StatusId, MatchId)
		SELECT b.transid
			, b.statusID
			, @MatchId
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
		WHERE b.matchid = @MatchId
			 AND b.betfrom <> 'P'
			 AND 1 = CASE WHEN @FilterBy IN (0,1) AND b.transid BETWEEN @MinSingleTransId AND @MaxSingleTransId THEN 1
						  WHEN @FilterBy = 2 AND b.checktime IS NOT NULL AND b.checktime BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
						  WHEN @FilterBy = 2 AND b.checktime IS NULL AND b.transdate BETWEEN @FilterFromTransTime AND @FilterToTransTime THEN 1
						  ELSE 0 
						  END
			AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						 ELSE 0 END
			AND 1 = CASE WHEN @IssueTypeId NOT IN (1) THEN 1 --NOT Danger Accept
						  ELSE CASE WHEN @SubIssueTypeId IN (55,57,60,75,79,82) AND b.bettype NOT IN (402,404,409,462,464) THEN 1 
									   WHEN @SubIssueTypeId IN (68,70) AND b.bettype NOT IN (483,485) THEN 1
									   WHEN @SubIssueTypeId IN (56,58,61,69,71,76) AND b.bettype NOT IN (401,403,407,461,463) THEN 1
									   WHEN @SubIssueTypeId IN (69,71) AND b.bettype NOT IN (482,484) THEN 1
									   WHEN @SubIssueTypeId IN (1,2,3,4,5,26,59,62,63,64,65,66,67,72,73,74,77,78,81,84,85) THEN 1
								       ELSE 0
							  END
					END
			

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												INNER JOIN MarkedTransaction mt WITH(NOLOCK) ON mt.TransId = rdt.transid AND mt.MatchId = rdt.MatchId
												LEFT JOIN #DangerAccept_SingleTickets tp ON rdt.TransId=tp.transid
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL
												  AND tr.TransId is NULL
												  AND rdt.RequestId=@RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		END

		IF @IsEditRequest = 1
		BEGIN
			SET @RequestDetailID_DA = (SELECT id FROM TicketVoiding_RequestDetail (NOLOCK) WHERE RequestId = @RequestId)
			
			DELETE s
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s
				LEFT JOIN #DangerAccept_SingleTickets t ON s.transid = t.transid AND t.matchid = @MatchId
			WHERE s.matchid = @MatchId AND s.RequestId = @RequestId AND t.transid IS NULL
			
			INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId)
			SELECT @RequestId
				, @IssueTypeId
				, @SubIssueTypeId
				, t.TransId
				, t.MatchId
				, @RequestDetailID_DA AS RequestDetailId
			FROM #DangerAccept_SingleTickets t
				LEFT JOIN TicketVoiding_RequestDetailTicket_Single st WITH (NOLOCK) ON st.transid = t.transid AND st.matchid = @MatchId
			WHERE st.transid IS NULL
		END
		ELSE
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId)
			SELECT @RequestId
				, @IssueTypeId
				, @SubIssueTypeId
				, t.TransId
				, t.MatchId
				, rd.Id AS RequestDetailId
			FROM #DangerAccept_SingleTickets t
				INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  
				OUTER APPLY (
									SELECT TOP 1 rs.TransId
									FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
										INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
									WHERE rs.TransId = t.transid
										AND rs.MatchId = @MatchId
										AND r.ActionId NOT IN (2)
							)tmp
			WHERE rd.RequestId = @RequestId AND tmp.TransId IS NULL
		END

		IF @ActionId <> 2
		BEGIN
			--Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #DangerAccept_SingleTickets t 
				WHERE isFinish IS NULL
					AND t.Matchid = @matchid
				
				IF @@ROWCOUNT = 0 BREAK
				
				SELECT @UnMarkedTransIds = STUFF(
					(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
					FROM @tmpTransIDBatch tp
					WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
						AND  tp.StatusId IN (0, 1) 
					GROUP BY TransId for XML PATH('')), 1, 1, ''
					)
		
				IF @UnMarkedTransIds IS NOT NULL
				BEGIN
					EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @UnMarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																	, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
				END	

				SET @UnMarkedTransIds = ''
			END
		END
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SingleTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
							  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)
							AND  tp.StatusId IN (0, 1) 
						GROUP BY TransId for XML PATH('')), 1, 1, ''
						)
				--Unmark ticket
				IF @MarkedTransIds IS NOT NULL
					BEGIN
						EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																			, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
					END												

					SET @MarkedTransIds = ''
			END
		END
	END
	ELSE IF @IssueTypeId IN (11,15) AND @TransIds IS NOT NULL
	BEGIN
		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId)
		SELECT DISTINCT @RequestId, @IssueTypeId, @SubIssueTypeId, val, @MatchId, tmp.Id AS RequestDetailId
		FROM dbo.f_SplitString(@TransIds, ',') l
			CROSS APPLY (
						SELECT rd.Id
						FROM dbo.bettrans b WITH(NOLOCK) 
							INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON b.matchid = rd.MatchId
						WHERE b.matchid = @MatchId AND rd.RequestId = @RequestId
							AND l.val = b.transid
						)tmp
		WHERE l.val <> ''
		OPTION (MAXRECURSION 0)
	END
	ELSE IF @IssueTypeId = 13  AND @UserNames IS NOT NULL --Abnormal Account
	BEGIN
		
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
		FROM dbo.f_SplitString(@UserNames, ',') l
			LEFT JOIN CustDB.dbo.custInfo ci WITH (NOLOCK) ON l.val = ci.username
		WHERE ci.custid IS NOT NULL
			AND val <> ''
		OPTION (MAXRECURSION 0)

		-- get SMA roleid = 2
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

		INSERT INTO @bettype_tmp (bettype, ProductID)
		SELECT DISTINCT pt.bettype, pt.ProductID
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
			AND pt.bettype NOT BETWEEN 1501 AND 1599   -- NOT IN Keno

		INSERT INTO #transIdTemp (transid, statusID, MatchId, bettype)
		SELECT	b.translogid AS transid
				,b.statusID  -- add new
				,b.eventID
				,b.gameID
		FROM	dbo.translog AS b WITH (NOLOCK)
			INNER JOIN #InputValidCustid_tmp c ON c.CustId = b.custid
		WHERE	b.winlostdate BETWEEN @FromWinlostDate AND @ToDate 
				AND b.GameID BETWEEN 801 AND 806
				AND 1 = CASE WHEN EXISTS (SELECT 1 FROM @Status_tmp WHERE statusID IN(0,1)) AND statusID = 0 THEN 1 ELSE 0 END
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

		-- Check exists in the request
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
			
		--Edit from to time of Abnormal account issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
											WHERE NOT EXISTS( SELECT TOP 1 1 FROM #transIdTemp tp WHERE rdt.TransId = tp.transid)
												  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = rdt.TransId)-- exist in # request
												  AND EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = rdt.transid)
												  AND rdt.RequestId = @RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		END

		--If all data are valid, Mark all running tickets
		IF @ActionId <> 2 -- store tickets of 'Manual Void', 'Waiting' & 'Void Instant' request
		BEGIN
			-- Remove transid exists request
			DELETE 
			FROM #transIdTemp
			WHERE transid IN ( SELECT transid FROM #TransidInRequest) 

			-- Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #transIdTemp t
					INNER JOIN @bettype_tmp pt ON t.bettype = pt.bettype
				WHERE isFinish IS NULL
					AND t.bettype NOT BETWEEN 801 AND 806 AND pt.ProductID NOT IN (3,5,27) -- Not mark ticket Metric Gaming, Number Game, Virtual Sport, Virtual Sports 2
					AND t.bettype NOT IN (38, 9, 29, 10) -- Bet Builder, Main Parlay, Outright
					  
				IF @@ROWCOUNT = 0 BREAK
				
				SELECT @UnMarkedTransIds = STUFF(
					(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
					FROM @tmpTransIDBatch tp
					WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
						AND  tp.StatusId IN (0, 1) 
					GROUP BY TransId for XML PATH('')), 1, 1, ''
					)
		
				IF @UnMarkedTransIds IS NOT NULL
				BEGIN
					EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @UnMarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																	, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
				END	

				SET @UnMarkedTransIds = ''
			END
		END
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #transIdTemp tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
							  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)
							AND  tp.StatusId IN (0, 1) 
						GROUP BY TransId for XML PATH('')), 1, 1, ''
						)
				--Unmark ticket
				IF @MarkedTransIds IS NOT NULL
					BEGIN
						EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																			, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
					END												

					SET @MarkedTransIds = ''
			END
		END

			--Search by TransIds
		IF (EXISTS(SELECT TOP 1 1 FROM #transIdTemp))
		BEGIN
			-- MG running tickets in translog
			INSERT INTO #SpecialDeleteBets(
				GroupID
				,bettype
				,transid
				,betid
				,refno	
				,hdp1
				,hdp2
				,odds
				,oddsspread
				,OddsType
				,STATUS
				,stake
				,transdate
				,betteam
				,betcheck
				,liveindicator	
				,modds
				,custid
				,livehomescore	
				,liveawayscore
				,matchid
				,winlost
				,TransDesc
				,betdaqid
				,username
				,recommend
				,CurrencyName
				,IsMarked	
			)
			SELECT	
				b.translogID AS GroupID
				,b.GameID
				,b.translogID as transid
				,0 AS BetID
				,b.translogID refno	
				,0 hdp1
				,0 hdp2
				,b.odds
				,0 AS oddsspread
				,b.custom1 OddsType
				,b.STATUS
				,b.stake
				,b.transdate
				,NULL betteam
				,NULL betcheck
				,b.liveindicator liveindicator
				,NULL modds
				,b.custid
				,NULL livehomescore
				,NULL liveawayscore
				,b.EventID
				,- b.actual_stake as winlost
				,b.transdesc
				,-1 -- normal ticket
				,b.username
				,recommend
				,b.CurrencyName
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			FROM dbo.translog AS b WITH (NOLOCK)
				INNER JOIN #transIdTemp temp
				ON b.translogid = temp.transid
				OUTER APPLY (
							SELECT TOP (1) TransId
							FROM dbo.MarkedTransaction WITH(NOLOCK) 
							WHERE b.translogid = TransId
						)m
			WHERE b.winlostdate >= @FromWinlostDate
				AND b.GameID BETWEEN 801 AND 806
				AND b.statusID = 0
				
			-- bettrans tickets	
			INSERT INTO #SpecialDeleteBets (
				GroupID			
				,bettype		
				,transid		
				,betid			
				,refno		
				,hdp1			
				,hdp2			
				,odds
				,oddsspread				
				,OddsType		
				,STATUS					
				,stake							
				,transdate		
				,betteam		
				,betcheck		
				,liveindicator	
				,modds			
				,custid						
				,livehomescore	
				,liveawayscore						
				,matchid					
				,winlost		
				,TransDesc		
				,betdaqid
				,username
				,recommend
				,ExtraInfo
				,MainCashoutId
				,CurrencyName
				,WalletType
				,RefCode
				,BonusID
				,IsMarked
			)
			SELECT	
				b.refno AS GroupId
				,b.bettype
				,b.transid
				,isnull(b.BetID, 0) AS BetID
				,b.refno			
				,b.hdp1
				,b.hdp2
				,b.odds
				,b.oddsspread
				,b.OddsType
				,CASE 
					WHEN b.STATUS = 'running'
						AND IsNull(b.SecAcceptFlag, 0) = 1
						AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS END AS STATUS
				,b.stake
				,b.transdate
				,b.betteam
				,b.betcheck
				,b.liveindicator
				,b.modds
				,b.custid
				,b.livehomescore
				,b.liveawayscore
				,b.matchid				
				,(b.winlost - b.actual_stake) winlost
				,b.transdesc
				,b.betdaqid
				,b.username
				,b.recommend			
				,b.ExtraInfo
				,CASE
					WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0 THEN b.transid
					ELSE NULL END AS MainCashoutId
				,b.CurrencyName
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN dbo.translog tl WITH(NOLOCK)
				ON b.custid 		= tl.custid
					AND b.refno 	= tl.translogid
					AND b.matchid 	= tl.eventid
				INNER JOIN #transIdTemp temp
				ON tl.translogid 	= temp.transid			
				OUTER APPLY (
							SELECT TOP (1) TransId
							FROM dbo.MarkedTransaction WITH(NOLOCK) 
							WHERE b.transid = TransId
						)m
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			WHERE	b.winlostdate >= @FromWinlostDate				
				AND b.bettype BETWEEN 801 AND 806 
				AND b.statusID NOT IN (0, 101, 102, 103)
			
			UNION ALL
			SELECT	
				b.transid AS GroupId
				,b.bettype
				,b.transid
				,isnull(b.BetID, 0) AS BetID
				,b.refno			
				,b.hdp1
				,b.hdp2
				,b.odds
				,b.oddsspread
				,b.OddsType
				,CASE 
					WHEN b.STATUS = 'running'
						AND IsNull(b.SecAcceptFlag, 0) = 1
						AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
					ELSE b.STATUS END AS STATUS
				,b.stake				
				,b.transdate
				,b.betteam
				,b.betcheck
				,b.liveindicator
				,b.modds
				,b.custid
				,b.livehomescore
				,b.liveawayscore				
				,b.matchid				
				,(b.winlost - b.actual_stake) winlost
				,b.transdesc
				,b.betdaqid
				,b.username
				,b.recommend			
				,b.ExtraInfo
				,CASE
					WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
							THEN b.transid
					ELSE NULL
				 END AS MainCashoutId
				,b.CurrencyName
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
			FROM dbo.bettrans AS b WITH (NOLOCK)
				INNER JOIN #transIdTemp temp
					ON b.transid = temp.transid
				OUTER APPLY (
							SELECT TOP (1) TransId
							FROM dbo.MarkedTransaction WITH(NOLOCK) 
							WHERE b.transid = TransId
						)m
				INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype				
			WHERE	b.winlostdate >= @FromWinlostDate				
				AND b.bettype NOT BETWEEN 801 AND 806-- MG
				AND b.statusID NOT IN (101, 102, 103)				
		END		
	
		-- delete cash-out member bet tickets
		DELETE t
		FROM #SpecialDeleteBets t
		WHERE EXISTS (SELECT TOP 1 1
					  FROM bettrans sub911 (NOLOCK)
					  WHERE sub911.bettype = 911
						AND sub911.transid = t.refno)	

		-- update MainTransId
		IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE refno IS NOT NULL)
		BEGIN
			UPDATE sub
			SET MainTransId = main.transid
			FROM #SpecialDeleteBets main
				 INNER JOIN #SpecialDeleteBets sub
						 ON main.RefCode = sub.RefCode	
							AND main.transid <> sub.transid					
							AND main.custid = sub.custid
							AND main.matchid = sub.matchid
							AND main.bettype = sub.bettype											
			WHERE main.WalletType = 1			
	  
			-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets	
			INSERT INTO #tmpRefCodeSummary (RefCode, custid, matchid, bettype, IsMarked, transid)
			SELECT RefCode, custid, matchid, bettype,IsMarked
				 , MAX(transid) AS transid
			FROM #SpecialDeleteBets
			WHERE	RefCode IS NOT NULL
			GROUP BY RefCode, custid, matchid, bettype,IsMarked
			HAVING COUNT(*) = 1
		
			IF @@ROWCOUNT > 0
			BEGIN
				INSERT INTO #SpecialDeleteBets (
						GroupID			
						,bettype		
						,transid		
						,betid			
						,refno		
						,hdp1			
						,hdp2			
						,odds					
						,OddsType		
						,STATUS					
						,stake							
						,transdate		
						,betteam		
						,betcheck		
						,liveindicator	
						,modds			
						,custid						
						,livehomescore	
						,liveawayscore							
						,matchid					
						,winlost		
						,TransDesc		
						,betdaqid
						,username
						,recommend		
						,ExtraInfo
						,MainCashoutId			
						,WalletType
						,RefCode
						,BonusID
						,MainTransId
						,IsMarked
					)
					SELECT	
						b.refno AS GroupId
						,b.bettype
						,b.transid
						,isnull(b.BetID, 0) AS BetID
						,b.refno			
						,b.hdp1
						,b.hdp2
						,b.odds
						,b.OddsType
						,CASE 
							WHEN b.STATUS = 'running'
								AND IsNull(b.SecAcceptFlag, 0) = 1
								AND IsNull(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
							ELSE b.STATUS END AS STATUS
						,b.stake
						,b.transdate
						,b.betteam
						,b.betcheck
						,b.liveindicator
						,b.modds
						,b.custid
						,b.livehomescore
						,b.liveawayscore				
						,b.matchid				
						,(b.winlost - b.actual_stake) winlost
						,b.transdesc
						,b.betdaqid
						,b.username
						,b.recommend			
						,b.ExtraInfo
						,CASE
							WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
									THEN b.transid
							ELSE NULL
						 END AS MainCashoutId
						,b.WalletType
						,b.RefCode
						,b.BonusID
						,t.transid AS MainTransId
						,t.IsMarked
				FROM #tmpRefCodeSummary t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON b.RefCode = t.RefCode
								AND b.transid <> t.transid					
								AND b.custid = t.custid
								AND b.matchid = t.matchid
								AND b.bettype = t.bettype
				WHERE b.statusID NOT IN (101, 102, 103) -- reject, void, refund	
			END	    			    				    					    				    					    
		END

		-- Delete main bettrade
		IF(EXISTS (SELECT TOP 1 1 
				   FROM #SpecialDeleteBets 
				   WHERE betdaqid = 0 AND extrainfo IS NULL))
		BEGIN
			DELETE FROM #SpecialDeleteBets WHERE betdaqid = 0 AND extrainfo IS NULL
		END

		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId)
		SELECT @RequestId
			,@IssueTypeId
			,@SubIssueTypeId
			,CASE WHEN s.bettype BETWEEN 801 AND 806 THEN s.refno ELSE s.transid END 
			,s.matchid
			,rd.Id AS RequestDetailId
		FROM #SpecialDeleteBets s
				INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					ON rd.RequestId = @RequestId AND s.MatchId = rd.MatchId

	END
	ELSE IF @IssueTypeId IN (3) --WC
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
		WHERE rd.MatchId = @MatchId AND req.RequestId <> @RequestId AND req.ActionId <>2

		INSERT INTO @bettype_tmp (bettype)
		SELECT DISTINCT pt.bettype
		FROM dbo.SportBettypeMatrix pt WITH (NOLOCK)
		WHERE pt.ProductID = 1 -- Sportsbook
		AND pt.bettype NOT IN (10, 9, 29) -- outright, parlay
		AND pt.bettype NOT BETWEEN 221 AND 227 -- Fast Market
		AND pt.SubProduct NOT IN ('Bet Builder', 'MG-SuperLive', 'BT-Comm', 'BT-Bought', 'BT-Sold', 'BT-Winloss') -- Bet Builder, Metric Gaming, Bet trade (BT-)

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
		FROM @WrongScoreInfoXML.nodes('root/r') t(c)
		OPTION (OPTIMIZE FOR (@WrongScoreInfoXML = NULL))
		
		INSERT INTO #DangerAccept_SingleTickets (TransId, StatusId, MatchId, LiveHomeScore, LiveAwayScore)
		SELECT b.transid
			, b.statusID
			, @MatchId
			, CASE WHEN f.GroupName = '2H' THEN s.LiveHomeScore ELSE b.livehomescore END AS livehomescore
			, CASE WHEN f.GroupName = '2H' THEN s.LiveAwayScore ELSE b.liveawayscore END AS liveawayscore
		FROM dbo.bettrans b WITH (NOLOCK)
			INNER JOIN @bettype_tmp bt ON bt.bettype = b.bettype
			INNER JOIN f_SD_GetGroupBettypes() f ON f.BetType = b.BetType
			CROSS APPLY (
				SELECT TOP(1) t.LiveHomeScore, t.LiveAwayScore 
				FROM #tblGetLogInfo t
				WHERE matchid = @MatchId
					AND 1 = CASE WHEN b.livehomescore = LiveHomeScore AND b.liveawayscore = LiveAwayScore AND b.transdate BETWEEN VoidFromTime AND VoidToTime THEN 1
								WHEN b.transdate BETWEEN VoidFromTime AND VoidToTime AND f.GroupName = '2H' THEN 1
							ELSE 0 END	
					AND b.transid BETWEEN MinSingleTransId AND MaxSingleTransId
			)s
		WHERE b.matchid = @MatchId
			AND 1 = CASE WHEN @ActionId <>2 AND b.statusID NOT IN (101, 102, 103) THEN 1
						 WHEN @ActionId = 2 AND b.statusID NOT IN (101, 103) THEN 1
						 ELSE 0 END
			AND b.betfrom <> 'P'
			AND 1 = CASE WHEN b.livehomescore = 0 AND b.liveawayscore = 0 AND b.liveindicator = 0 AND f.GroupName <> '2H' THEN 0 ELSE 1 END

		SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
		------------------------------------------------------------------------------------------------------------
		--Edit from to time of Danger Accepted issue -> unmark ticket change void time
		SELECT @RemoveTransIds = STUFF((SELECT ',' + CAST(rdt.transid AS VARCHAR(50)) 
											FROM dbo.TicketVoiding_RequestDetailTicket_Single rdt WITH(NOLOCK)
												INNER JOIN MarkedTransaction mt WITH(NOLOCK) ON mt.TransId = rdt.transid AND mt.MatchId = rdt.MatchId
												LEFT JOIN #DangerAccept_SingleTickets tp ON rdt.TransId=tp.transid
												LEFT JOIN #TransidInRequest tr on tr.TransId = rdt.TransId
											WHERE tp.TransId IS NULL
												  AND tr.TransId is NULL
												  AND rdt.RequestId=@RequestId
											FOR XML PATH('')
										), 1,1,'')
		IF @RemoveTransIds IS NOT NULL
		BEGIN
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
		END

		IF @IsEditRequest = 1
		BEGIN			
			DELETE s
			FROM dbo.TicketVoiding_RequestDetailTicket_Single s
				LEFT JOIN #DangerAccept_SingleTickets t ON s.transid = t.transid AND t.matchid = @MatchId
			WHERE s.matchid = @MatchId AND s.RequestId = @RequestId AND t.transid IS NULL
			
			INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId)
			SELECT @RequestId
				, @IssueTypeId
				, @SubIssueTypeId
				, t.TransId
				, t.MatchId
				, rd.Id AS RequestDetailId
			FROM #DangerAccept_SingleTickets t
				INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  AND rd.LiveHomeScore = t.LiveHomeScore AND rd.LiveAwayScore = t.LiveAwayScore
				OUTER APPLY (
									SELECT TOP 1 rs.TransId
									FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
										INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
									WHERE rs.TransId = t.transid
										AND rs.MatchId = @MatchId
										AND r.ActionId NOT IN (2)
							)tmp
			WHERE rd.RequestId = @RequestId AND tmp.TransId IS NULL
		END
		ELSE
		BEGIN
			INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId)
			SELECT @RequestId
				, @IssueTypeId
				, @SubIssueTypeId
				, t.TransId
				, t.MatchId
				, rd.Id AS RequestDetailId
			FROM #DangerAccept_SingleTickets t
				INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) ON t.MatchId = rd.MatchId  AND rd.LiveHomeScore = t.LiveHomeScore AND rd.LiveAwayScore = t.LiveAwayScore
				OUTER APPLY (
									SELECT TOP 1 rs.TransId
									FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
										INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
									WHERE rs.TransId = t.transid
										AND rs.MatchId = @MatchId
										AND r.ActionId NOT IN (2)
							)tmp
			WHERE rd.RequestId = @RequestId AND tmp.TransId IS NULL
		END

		IF @ActionId <> 2
		BEGIN
			--Mark Ticket
			WHILE (1=1)
			BEGIN
				DELETE @tmpTransIDBatch
					
				UPDATE TOP(2000) t
					SET isFinish = 1
				OUTPUT DELETED.TransId, DELETED.StatusId					
				INTO @tmpTransIDBatch(TransId, StatusId)
				FROM #DangerAccept_SingleTickets t 
				WHERE isFinish IS NULL
					AND t.Matchid = @matchid
				
				IF @@ROWCOUNT = 0 BREAK
				
				SELECT @UnMarkedTransIds = STUFF(
					(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
					FROM @tmpTransIDBatch tp
					WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
						AND  tp.StatusId IN (0, 1) 
					GROUP BY TransId for XML PATH('')), 1, 1, ''
					)
		
				IF @UnMarkedTransIds IS NOT NULL
				BEGIN
					EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @UnMarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
																	, @MarkType = 1, @LogActionId = 90508, @IsLockMatch = 0
				END	

				SET @UnMarkedTransIds = ''
			END
		END
		ELSE -- take note
		BEGIN
			IF @IsEditRequest = 1
			BEGIN
				SELECT @MarkedTransIds = STUFF(
						(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
						FROM #DangerAccept_SingleTickets tp
						WHERE EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
							  AND NOT EXISTS ( SELECT TOP 1 1 FROM #TransidInRequest tr WHERE tr.TransId = tp.TransId)
							AND  tp.StatusId IN (0, 1) 
						GROUP BY TransId for XML PATH('')), 1, 1, ''
						)
				--Unmark ticket
				IF @MarkedTransIds IS NOT NULL
					BEGIN
						EXEC dbo.Nap_SpecialDelete_MarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP
																			, @RequestId = @RequestId, @LogActionId = 90501, @IsLockMatch = 0
					END												

					SET @MarkedTransIds = ''
			END
		END
	END
	ELSE --EKO,WKO
	BEGIN
		IF @IsEditRequest = 1
		BEGIN
			DELETE dbo.TicketVoiding_RequestDetailTicket_Single
			WHERE RequestId = @RequestId
		END
		-- search tickets : not metric gaming tickets, mix parlay tickets
		INSERT INTO #SpecialDeleteBets(
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid	
				,ExtraInfo
				,MainCashoutId
				,WalletType
				,RefCode
				,BonusID
				,WinLost
				,IsMarked
				,LiveIndicator
				,matchid
			)
		SELECT 
				b.transid AS GroupID
				,b.transid
				,b.transid AS SubTransID
				,b.refno
				,b.custid
				,b.odds
				,b.odds AS SubOdds
				,b.oddsspread			
				,b.OddsType
				,b.transdate
				,b.bettype
				,b.betteam
				,b.betteam AS SubBetteam
				,b.betcheck
				,b.betcheck AS SubBetcheck
				,b.hdp1
				,b.hdp2
				,b.livehomescore
				,b.liveawayscore
				,b.creator
				,b.stake
				,b.CurrencyName
				,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.STATUS
					END AS STATUS
				,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						ELSE b.STATUS
					END AS SubStatus
				,b.srecommend
				,b.mrecommend
				,b.recommend
				,b.betid
				,b.Transdesc
				,b.betdaqid
				,b.ExtraInfo
				,CASE
					WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
							THEN b.transid
					ELSE NULL
				 END AS MainCashoutId
				,b.WalletType
				,b.RefCode
				,b.BonusID
				,b.WinLost - b.actual_stake AS WinLost
				,CASE WHEN m.TransId IS NULL THEN 0 ELSE 1 END AS IsMarked
				,b.liveindicator
				,b.matchid
		FROM	bettrans b WITH (NOLOCK)	
		   LEFT JOIN dbo.MarkedTransaction m WITH(NOLOCK) ON b.transid = m.TransId	
			OUTER APPLY (
							SELECT TOP 1 rs.TransId
							FROM dbo.TicketVoiding_RequestDetailTicket_Single rs WITH (NOLOCK)
								INNER JOIN TicketVoiding_Request r WITH (NOLOCK) ON r.RequestId = rs.RequestId 
							WHERE rs.TransId = b.transid
								AND rs.MatchId = @MatchId
								AND r.ActionId NOT IN (2)
					)tmp
		WHERE	b.matchid = @matchid
				AND b.transdate >= @KickOffTime
				AND b.statusID NOT IN (101, 102, 103) -- reject, void, refund
				AND b.liveindicator = 0
				AND b.bettype NOT IN (805, 806, 9, 29)			
				AND b.bettype NOT BETWEEN 901 AND 920
				AND b.betfrom <> 'P'
				AND tmp.TransId IS NULL

		-- delete cash-out member bet tickets
		DELETE t
		FROM #SpecialDeleteBets t
		WHERE EXISTS (SELECT TOP 1 1
					  FROM bettrans sub911 (NOLOCK)
					  WHERE sub911.bettype = 911
						AND sub911.transid = t.refno)				    	
		
		-- update MainTransId
		IF EXISTS (SELECT TOP 1 1 FROM #SpecialDeleteBets WHERE RefCode IS NOT NULL)
		BEGIN
			UPDATE sub
			SET MainTransId = main.transid
			FROM #SpecialDeleteBets main
				 INNER JOIN #SpecialDeleteBets sub
						 ON main.RefCode = sub.RefCode
							AND main.transid <> sub.transid	
							AND main.custid = sub.custid
							AND main.bettype = sub.bettype
			WHERE main.WalletType = 1					
		  
			-- Insert more bonus or cash ticket in case only one ticket appears in #SpecialDeleteBets  
			INSERT INTO #tmpRefCodeSummary(RefCode, custid, bettype, IsMarked, transid)
			SELECT RefCode, custid, bettype, IsMarked
				 , MAX(transid) AS transid
			FROM #SpecialDeleteBets
			WHERE	RefCode IS NOT NULL
			GROUP BY RefCode, custid, bettype, IsMarked
			HAVING COUNT(*) = 1

			IF @@ROWCOUNT > 0
			BEGIN	
				INSERT INTO #SpecialDeleteBets(
							GroupID			
							,transid		
							,SubTransid		
							,refno			
							,custid			
							,odds			
							,SubOdds		
							,oddsspread
							,OddsType		
							,transdate		
							,bettype 		
							,betteam 		
							,SubBetTeam
							,betcheck	
							,SubBetcheck	
							,hdp1 			
							,hdp2 			
							,livehomescore 	
							,liveawayscore 	
							,creator		
							,Stake			
							,currencyname		
							,STATUS			
							,SubStatus	
							,srecommend
							,mrecommend		
							,recommend		
							,betid			
							,Transdesc		
							,betdaqid
							,ExtraInfo	
							,MainCashoutId
							,WalletType
							,RefCode
							,BonusID
							,MainTransId
							,WinLost
							,IsMarked
							,LiveIndicator
							,matchid
						)
					SELECT 
							b.transid AS GroupID
							,b.transid
							,b.transid AS SubTransID
							,b.refno
							,b.custid
							,b.odds
							,b.odds AS SubOdds
							,b.oddsspread
							,b.OddsType
							,b.transdate
							,b.bettype
							,b.betteam
							,b.betteam AS SubBetteam
							,b.betcheck
							,b.betcheck AS SubBetcheck
							,b.hdp1
							,b.hdp2
							,b.livehomescore
							,b.liveawayscore
							,b.creator
							,b.stake
							,b.CurrencyName
							,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								  ELSE b.STATUS
							 END AS STATUS
							,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
								  ELSE b.STATUS
							 END AS SubStatus
							,b.srecommend
							,b.mrecommend
							,b.recommend
							,b.betid
							,b.Transdesc
							,b.betdaqid
							,b.ExtraInfo
							,CASE
								WHEN b.betdaqid = 0 AND charindex ('p25',b.extrainfo)> 0
										THEN b.transid
								ELSE NULL
							 END AS MainCashoutId
							,b.WalletType
							,b.RefCode
							,b.BonusID
							,t.transid AS MainTransId
							,b.winlost - b.actual_stake AS WinLost
							,t.IsMarked
							,b.liveindicator
							,b.matchid
				FROM #tmpRefCodeSummary t
					 INNER JOIN dbo.bettrans b WITH (NOLOCK)
							 ON b.RefCode = t.RefCode
								AND b.transid <> t.transid
								AND b.matchid = @MatchId
								AND b.custid = t.custid
								AND b.bettype = t.bettype 
				WHERE b.statusID NOT IN (101,102, 103 ) -- reject, void, refund	
			END  			    				    					    				    					    	
		END

		UPDATE	main
			SET main.SoldId = sub.transid
		OUTPUT INSERTED.SoldId
		INTO #tblSoldTicket(transid)
		FROM #SpecialDeleteBets main 
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND main.betdaqid = 0 -- main ticket is BTrade
					AND main.extrainfo is null
					AND sub.matchid = @MatchId
					AND sub.bettype = 901
			
		-- get sub ticket of BetTrade (901)
		INSERT INTO #SpecialDeleteBets (
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds			
				,SubOdds	
				,oddsspread			
				,OddsType		
				,transdate		
				,bettype
				,OriginalBetType 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid
				,ExtraInfo
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
				,IsMarked
				,LiveIndicator
				,matchid
			)
		SELECT  main.transid AS GroupTransId
				,sub.transid AS transId
				,sub.transid AS SubTransId
				,sub.refno
				,sub.custid
				,main.odds
				,main.odds AS SubOdds
				,main.oddsspread
				,main.OddsType
				,sub.transdate
				,sub.bettype
				,main.bettype  AS OriginalBetType
				,main.betteam
				,main.SubBetTeam
				,main.betcheck
				,main.SubBetcheck
				,main.hdp1
				,main.hdp2			
				,main.livehomescore
				,main.liveawayscore
				,sub.creator
				,main.Stake
				,main.CurrencyName
				,'SOLD'
				,'SOLD' AS SubStatus
				,main.srecommend
				,main.mrecommend
				,main.recommend			
				,main.bettype AS betid
				,sub.transdesc
				,sub.betdaqid
				,sub.ExtraInfo
				,sub.WalletType
				,sub.RefCode
				,sub.BonusID
				,main.transid AS MainTransId
				,sub.winlost - sub.actual_stake AS WinLost
				,main.IsMarked
				,main.LiveIndicator
				,sub.matchid
		FROM	#SpecialDeleteBets main
			INNER JOIN dbo.bettrans sub WITH(NOLOCK)
				ON	main.transid = sub.refno
					AND sub.matchid = @MatchId
					AND sub.bettype = 901
			INNER JOIN #tblSoldTicket sold 
				ON sold.transid = sub.transid
				
		-- get sub ticket of Cash-out (911)
		INSERT INTO #SpecialDeleteBets (
				GroupID			
				,transid		
				,SubTransid		
				,refno			
				,custid			
				,odds					
				,SubOdds
				,oddsspread				
				,OddsType		
				,transdate		
				,bettype
				,OriginalBetType 		
				,betteam 		
				,SubBetTeam
				,betcheck	
				,SubBetcheck	
				,hdp1 			
				,hdp2 			
				,livehomescore 	
				,liveawayscore 	
				,creator		
				,Stake			
				,currencyname		
				,STATUS			
				,SubStatus	
				,srecommend
				,mrecommend		
				,recommend		
				,betid			
				,Transdesc		
				,betdaqid
				,ExtraInfo	
				,MainCashoutId
				,matchid
				,WalletType
				,RefCode
				,BonusID
				,MainTransId
				,WinLost
				,IsMarked
				,LiveIndicator
			)
		SELECT  sub911.transid AS GroupTransId
				,sub911.transid AS transId
				,sub911.transid AS SubTransId
				,sub911.refno
				,sub911.custid
				,main.odds
				,main.odds AS SubOdds
				,main.oddsspread
				,main.OddsType
				,sub911.transdate
				,sub911.bettype
				,main.bettype AS OriginalBetType
				,main.betteam
				,main.SubBetTeam
				,main.betcheck
				,main.SubBetcheck
				,main.hdp1
				,main.hdp2			
				,main.livehomescore
				,main.liveawayscore
				,sub911.creator
				,sub911.Stake
				,main.CurrencyName
				,'Cash out'
				,'Cash out' AS SubStatus
				,main.srecommend
				,main.mrecommend
				,main.recommend			
				,main.bettype AS betid
				,sub911.transdesc
				,sub911.betdaqid
				,sub911.ExtraInfo
				,main.transid AS MainCashoutId
				,sub911.matchid	
				,sub911.WalletType
				,sub911.RefCode
				,sub911.BonusID
				,main.transid AS MainTransId
				,sub911.winlost - sub911.actual_stake AS WinLost
				,main.IsMarked
				,main.LiveIndicator
		FROM dbo.bettrans sub911 WITH(NOLOCK)
			 INNER JOIN #SpecialDeleteBets main 
					ON	sub911.refno = main.transid	
						AND sub911.custid = main.custid					
						AND main.betdaqid = 0
						AND charindex ('p25',main.extrainfo)> 0			
						AND sub911.bettype = 911
						AND sub911.matchid = @matchid
		WHERE sub911.statusID NOT IN (102, 101, 103) -- VOID, REJECT, refund					
		
		-- get cash-out member bet tickets	
		INSERT INTO #SpecialDeleteBets(
					GroupID			
					,transid		
					,SubTransid		
					,refno			
					,custid			
					,odds			
					,SubOdds	
					,oddsspread				
					,OddsType		
					,transdate		
					,bettype 
					,OriginalBetType		
					,betteam 		
					,SubBetTeam
					,betcheck	
					,SubBetcheck	
					,hdp1 			
					,hdp2 			
					,livehomescore 	
					,liveawayscore 	
					,creator		
					,Stake			
					,currencyname		
					,STATUS			
					,SubStatus	
					,srecommend
					,mrecommend		
					,recommend		
					,betid			
					,Transdesc		
					,betdaqid
					,ExtraInfo
					,IsCashOutMemberTicket
					,MainCashoutId
					,WalletType
					,RefCode
					,BonusID
					,MainTransId
					,WinLost
					,IsMarked
					,LiveIndicator
					,matchid
				)
			SELECT  sub911.transid AS GroupID
					,b.transid
					,b.transid AS SubTransID
					,b.refno
					,b.custid
					,b.odds
					,b.odds AS SubOdds
					,b.oddsspread
					,b.OddsType
					,b.transdate
					,b.bettype
					,sub911.OriginalBetType
					,b.betteam
					,b.betteam AS SubBetteam
					,b.betcheck
					,b.betcheck AS SubBetcheck
					,b.hdp1
					,b.hdp2
					,b.livehomescore
					,b.liveawayscore
					,b.creator
					,b.stake
					,b.CurrencyName
					,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						  ELSE b.STATUS
					 END AS STATUS
					,CASE WHEN b.STATUS = 'running' AND ISNULL(b.SecAcceptFlag, 0) = 1 AND ISNULL(b.checktime, CURRENT_TIMESTAMP) > CURRENT_TIMESTAMP THEN 'waiting'
						  ELSE b.STATUS
					 END AS SubStatus
					,b.srecommend
					,b.mrecommend
					,b.recommend
					,b.betid
					,b.Transdesc
					,b.betdaqid
					,b.ExtraInfo
					,CAST(1 AS BIT)  AS IsCashOutMemberTicket
					,sub911.MainCashoutId AS MainCashoutId
					,b.WalletType
					,b.RefCode
					,b.BonusID
					,sub911.MainTransId
					,b.winlost - b.actual_stake AS WinLost
					,sub911.IsMarked
					,b.liveindicator
					,b.matchid
		FROM #SpecialDeleteBets sub911
			 CROSS APPLY (
							  SELECT b.transid, b.refno, b.custid, b.oddsid, b.oddsspread, b.oddstype, b.transdate, b.bettype, b.betteam, b.betcheck, b.status
									,b.hdp1, b.hdp2, b.livehomescore, b.liveawayscore, b.creator, b.stake, b.CurrencyName, b.SecAcceptFlag, b.checktime, b.odds
									,b.srecommend, b.mrecommend, b.recommend, b.betid, b.transdesc, b.betdaqid, b.ExtraInfo, b.WalletType, b.RefCode, b.BonusID, b.winlost, b.actual_stake,liveindicator,matchid
							  FROM dbo.bettrans b WITH (NOLOCK)
							  WHERE b.refno = sub911.transid
								AND b.matchid = sub911.matchid					
								AND b.bettype = sub911.OriginalBetType
								AND b.statusID NOT IN (102, 101, 103) -- VOID, REJECT, refund
						 ) AS b
		WHERE sub911.bettype = 911

		INSERT INTO dbo.TicketVoiding_RequestDetailTicket_Single (RequestId, IssueTypeId, SubIssueTypeId, TransId, MatchId, RequestDetailId)
		SELECT @RequestId
			,@IssueTypeId
			,@SubIssueTypeId
			,s.transid
			,s.matchid
			,rd.Id AS RequestDetailId
		FROM #SpecialDeleteBets s
			INNER JOIN dbo.TicketVoiding_RequestDetail rd WITH(NOLOCK) 
					ON rd.RequestId = @RequestId AND rd.MatchId = s.matchid

	END

	DROP TABLE #SpecialDeleteBets
	DROP TABLE #tblSoldTicket
	DROP TABLE #tmpRefCodeSummary
	DROP TABLE #DangerAccept_SingleTickets
	DROP TABLE #TransidInRequest
	DROP TABLE #InputUsernameList
	DROP TABLE #InputValidCustid_2
	DROP TABLE #InputValidCustid_tmp
	DROP TABLE #transIdTemp
END