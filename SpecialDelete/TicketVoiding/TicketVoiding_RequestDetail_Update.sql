/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Update]
(
	@RequestId				INT
	,@MatchId				VARCHAR(MAX) = NULL
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
	,@IsCheckedHomeTeam		BIT = NULL
	,@IsCheckedAwayTeam		BIT = NULL
	,@SubIssueTypeId		TINYINT = NULL
	,@IsConfirmCalculator   BIT = 0
	,@UserNames				VARCHAR(MAX) = NULL
	,@ProductIds			VARCHAR(50)  = NULL
	,@StatusIds				VARCHAR(50)  = NULL
	,@FromDate				DATETIME     = NULL
    ,@ToDate				DATETIME     = NULL
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
		- 20201106@July: [TVS] - Abnormal Account [Redmine: #143666]

	Param's explanation:	
	
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
			,@OldFilterFromTransTime DATETIME = NULL
			,@OldFilterToTransTime	 DATETIME = NULL
			,@OldFilterFromBetId	 BIGINT = NULL
			,@OldFilterToBetId		 BIGINT = NULL
			,@OldFilterBy			 TINYINT = 0
			,@ResettleTransids       VARCHAR(MAX) = '' 
			,@UnmarkTransids		 VARCHAR(MAX) =''
			,@RemoveTransIds		 VARCHAR(MAX) =''
			,@OldUserNames			 VARCHAR(MAX) = NULL
			,@OldFromDate			 DATETIME     = NULL
			,@OldToDate				 DATETIME     = NULL

	CREATE TABLE #inputTransid (transid BIGINT)
	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, groupid INT, StatusId INT, statuswinlost TINYINT)
	CREATE TABLE #TransidInRequest (TransId BIGINT)

	CREATE TABLE #TempEditMatchID ( MatchID INT, IsFlag BIT) -- 0 Remove, 1 -- Add username -> match
	CREATE TABLE #TempMatch (MatchID INT)
	 
	IF CHARINDEX (',', @MatchId) = 0
	BEGIN
		 SET @MatchId = CAST (@MatchId AS INT)
	END
	ELSE
	BEGIN
		INSERT INTO #TempMatch (MatchId)
		SELECT  DISTINCT l.val
		FROM dbo.f_SplitString(@MatchId, ',') l
		WHERE l.val <> ''
		OPTION (maxrecursion 0)
	END

	SET @StartTime = GETDATE()
	SET @LogActionId = 90003
	SET @SB_Error = 0

	
	IF @IssueTypeId = 11 OR @TransIds IS NOT NULL -- Abnormal Bet
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
				,RequestType = CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
		WHERE	RequestId = @RequestId
	END
	ELSE IF @IssueTypeId IN (1, 10) -- Danger Accept, Red Card
	BEGIN
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET @OldFilterFromTransTime = FilterFromTransTime
			, @OldFilterToTransTime = FilterToTransTime
			, @OldFilterFromBetId = FilterFromBetId
			, @OldFilterToBetId = FilterToBetId
			, @OldFilterBy = FilterBy
			, FilterFromTransTime = @FilterFromTransTime
			, FilterToTransTime = @FilterToTransTime
			, FilterFromBetId = @FilterFromBetId
			, FilterToBetId = @FilterToBetId
			, FilterBy = @FilterBy
			, SingleCount = @SingleCount
			, MainParlayCount = @MainParlayCount
			, MinSingleTransId = @MinSingleTransId
			, MaxSingleTransId = @MaxSingleTransId
			, MinMainParlayTransId = @MinMainParlayTransId
			, MaxMainParlayTransId = @MaxMainParlayTransId
			, VoidFromTime = @VoidFromTime
			, VoidToTime = @VoidToTime
			, IssueDetail = @LiveScores
			, IsCheckedHomeTeam = @IsCheckedHomeTeam
			, IsCheckedAwayTeam = @IsCheckedAwayTeam

		WHERE	RequestId = @RequestId
	END
	ELSE IF @IssueTypeId = 13 -- Abnormal Account
	BEGIN

		SELECT   @OldUserNames	= UserNames
				, @OldFromDate	= FromWinlostDate
				, @OldToDate	= ToWinlostDate
		FROM dbo.TicketVoiding_RequestDetail WITH(NOLOCK)
		WHERE RequestId = @RequestId 

		INSERT INTO #TempEditMatchID (MatchID, IsFlag)
		SELECT rd.MatchId, 0 -- remove match
		FROM  dbo.TicketVoiding_RequestDetail rd WITH (NOLOCK)
		WHERE  NOT EXISTS ( SELECT TOP 1 1 FROM #TempMatch m WHERE rd.MatchId = m.MatchID)
			 AND rd.RequestId = @RequestId
		UNION ALL
		SELECT m.MatchId, 1  -- add match
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
				FROM dbo.TicketVoiding_RequestDetail rd
					INNER JOIN #TempEditMatchID e ON  rd.MatchId = e.MatchID
				WHERE rd.RequestId = @RequestId AND IsFlag = 0
		END
		ELSE IF EXISTS (SELECT TOP 1 1 FROM #TempEditMatchID WHERE IsFlag = 1)
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
					, m.homeid
					, m.awayid
					, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
				FROM #TempEditMatchID e 
					INNER JOIN dbo.match m WITH(NOLOCK) ON e.MatchID = m.matchid AND e.IsFlag = 1		
		END  
		
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET   UserNames =  @UserNames
				, ProductIds = @ProductIds
				, TicketStatusIds = @StatusIds
				, FromWinlostDate = @FromDate
				, ToWinlostDate = @ToDate
		WHERE	RequestId = @RequestId
	END
	ELSE --EKO, WKO
	BEGIN
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET	@OldKickOffTime = KickOffTime
				,KickOffTime = ISNULL(@KickOffTime, KickOffTime)
		WHERE	RequestId = @RequestId
				AND MatchId = @MatchId
	END

	-- Auto mark ticket running for auto void
	IF @IssueTypeId = 11 AND @Sporttype <= 99
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
			EXEC dbo.Nap_SpecialDelete_MarkedTickets_ManualUpdate @TransIds = @RemoveTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId, @LogActionId = 90501
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
															, @MarkType = 1, @LogActionId = 90508
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
				EXEC dbo.Nap_SpecialDelete_MarkedTickets_ManualUpdate @TransIds = @UnmarkTransids, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId, @LogActionId = 90501
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
		
		IF @ActionId = 4 OR (@ActionID = 1 AND @IsCalQueue = 1 AND @IsTransidProcessed = 1)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			VALUES(@RequestId, @MatchId, CASE WHEN @ActionId = 1 THEN 'AddRequest' ELSE 'VoidInstant' END, 0, 10278938, GETDATE(), '125.227.140.97', @Sporttype)
		END
	END

	-- Get content of log data
	SET @LogDataContent = ''
	IF @IssueTypeId = 11 OR @TransIds IS NOT NULL
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
		IF @OldFilterBy <> @FilterBy
		BEGIN
			SET @LogDataContent += ' Old FilterBy: ' + CAST(@OldFilterBy AS VARCHAR(10))
								+ ' New FilterBy: ' + CAST(@FilterBy AS VARCHAR(10))
			IF @FilterBy <> 0 
			BEGIN
				SET @LogDataContent += ', From: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21) + ', To: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
			END
			ELSE
			BEGIN
				SET @LogDataContent += ', From: ' + CAST(@FilterFromBetId AS VARCHAR(20)) + ', To: ' + CAST(@FilterToBetId AS VARCHAR(20))
			END

		END
		IF @FilterBy <> 0 AND @OldFilterFromTransTime <> @FilterFromTransTime
		BEGIN
			SET @LogDataContent += ' Old From Transdate: ' + CONVERT(VARCHAR(30), @OldFilterFromTransTime, 21)
								+ ' New From Transdate: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21)
		END
		ELSE IF @FilterBy <> 0 AND @OldFilterToTransTime <> @FilterToTransTime
		BEGIN
			SET @LogDataContent += ' Old To Transdate: ' + CONVERT(VARCHAR(30), @OldFilterToTransTime, 21)
								+ ' New To Transdate: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
		END
		ELSE IF @FilterBy = 0 AND @OldFilterFromBetId <> @FilterFromBetId
		BEGIN
			SET @LogDataContent += ' Old From BetID: ' + CAST(@OldFilterFromBetId AS VARCHAR(20))
									+ ' New From BetID: ' + CAST(@FilterFromBetId AS VARCHAR(20))
		END
		ELSE IF @FilterBy = 0 AND @OldFilterToBetId <> @FilterToBetId
		BEGIN
			SET @LogDataContent += ' Old To BetID: ' + CAST(@OldFilterToBetId AS VARCHAR(20))
									+ ' New To BetID: ' + CAST(@FilterToBetId AS VARCHAR(20))
		END
		IF @IssueTypeId IN (1, 10) AND @SubIssueTypeId IN (1, 2)
		BEGIN
			SET @LogDataContent += 'IsCheckedHomeTeam: '+ CAST(@IsCheckedHomeTeam AS VARCHAR(20)) + ', IsCheckedAwayTeam: ' + CAST(@IsCheckedAwayTeam AS VARCHAR(20))
		END
	END
	ELSE IF @IssueTypeId = 13
	BEGIN
		IF @OldFromDate <> @FromDate
		BEGIN
			SET @LogDataContent += ' Old From Date: ' + CONVERT(VARCHAR(30), @OldFromDate, 21)
								+ ' New From Date: ' + CONVERT(VARCHAR(30), @FromDate, 21)
		END
		IF @OldToDate <> @ToDate
		BEGIN
			SET @LogDataContent += ' Old To Date: ' + CONVERT(VARCHAR(30), @OldToDate, 21)
								+ ' New To Date: ' + CONVERT(VARCHAR(30), @ToDate, 21)
		END
		IF @OldUserNames <> @UserNames
		BEGIN
			SET @LogDataContent += ' Old Usernames: ' + @OldUserNames + ' New Usernames: ' + @UserNames
		END
	END
	ELSE
	BEGIN
		IF @OldKickOffTime <> @KickOffTime
		BEGIN
			SET @LogDataContent += ' Old KickOffTime: ' + CONVERT(VARCHAR(30), @OldKickOffTime, 21)
								+ ' New KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
		END
	END

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

END
GO