/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Update]
(
	@RequestId		INT
	,@MatchId		INT
	,@KickOffTime	DATETIME	 = NULL

	,@UserId		INT
	,@IP			VARCHAR(50)	 = NULL
	,@TransIds 		VARCHAR(MAX) = NULL
	,@ActionId		TINYINT
	,@IssueTypeId	TINYINT
	,@FilterFromTransTime DATETIME = NULL
	,@FilterToTransTime DATETIME = NULL
	,@FilterFromBetId BIGINT = NULL
	,@FilterToBetId BIGINT = NULL
	,@IsFilterByTransTime BIT = NULL
	,@SingleCount INT = NULL
	,@MainParlayCount INT = NULL
	,@MinSingleTransId BIGINT = NULL
	,@MaxSingleTransId BIGINT = NULL
	,@MinMainParlayTransId BIGINT = NULL
	,@MaxMainParlayTransId BIGINT = NULL
	,@VoidFromTime DATETIME = NULL
	,@VoidToTime DATETIME = NULL
	,@LiveHomeScore TINYINT = NULL
	,@LiveAwayScore TINYINT = NULL
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

	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@LogDataContent	VARCHAR(MAX)
			,@SB_Error			BIT

			,@OldKickOffTime	DATETIME
			
			,@LeagueId			INT = NULL
			,@HomeId			INT = NULL
			,@AwayId			INT = NULL
			,@Sporttype			SMALLINT = NULL
			,@OldMatchId			INT
			,@OldTransIds 		VARCHAR(MAX) = NULL
			,@MarkedTransIds	VARCHAR(MAX)
			,@Username			NVARCHAR(200)
			,@IsCalQueue	BIT = 0
			,@IsTransidProcessed BIT = 0
			,@OldFilterFromTransTime DATETIME = NULL
			,@OldFilterToTransTime DATETIME = NULL
			,@OldFilterFromBetId BIGINT = NULL
			,@OldFilterToBetId BIGINT = NULL
			,@OldIsFilterByTransTime BIT = NULL

	CREATE TABLE #inputTransid (transid BIGINT)
	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, groupid INT, StatusId INT, statuswinlost TINYINT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90003
	SET @SB_Error = 0

	
	IF @IssueTypeId = 11 OR @TransIds IS NOT NULL
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
	ELSE IF @IssueTypeId = 1
	BEGIN
		UPDATE	dbo.TicketVoiding_RequestDetail WITH(ROWLOCK, UPDLOCK)
			SET @OldFilterFromTransTime = FilterFromTransTime
			, @OldFilterToTransTime = FilterToTransTime
			, @OldFilterFromBetId = FilterFromBetId
			, @OldFilterToBetId = FilterToBetId
			, @OldIsFilterByTransTime = IsFilterByTransTime
			, FilterFromTransTime = @FilterFromTransTime
			, FilterToTransTime = @FilterToTransTime
			, FilterFromBetId = @FilterFromBetId
			, FilterToBetId = @FilterToBetId
			, IsFilterByTransTime = @IsFilterByTransTime
			, SingleCount = @SingleCount
			, MainParlayCount = @MainParlayCount
			, MinSingleTransId = @MinSingleTransId
			, MaxSingleTransId = @MaxSingleTransId
			, MinMainParlayTransId = @MinMainParlayTransId
			, MaxMainParlayTransId = @MaxMainParlayTransId
			, VoidFromTime = @VoidFromTime
			, VoidToTime = @VoidToTime
			, LiveHomeScore = @LiveHomeScore
			, LiveAwayScore = @LiveAwayScore

		WHERE	RequestId = @RequestId
	END
	ELSE
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
		
		INSERT INTO #inputTransid (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)

		INSERT INTO #transid_tmp (transid, bettype, StatusId,statuswinlost)
		SELECT t.transid, b.bettype, b.statusID, b.statuswinlost
		FROM #inputTransid t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
		WHERE b.statusID IN (0, 1)

		SET @IsCalQueue = ( SELECT TOP (1) 1
							FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
							WHERE StatusId IN (1,2,4) AND matchid = @MatchId AND RequestId = 0
							)
		
		IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE statusid = 0 AND statuswinlost IS NOT NULL)
			SET @IsTransidProcessed = 1
		
		-- mark ticket
		SELECT @MarkedTransIds = STUFF(
			(SELECT ',' + CONVERT(VARCHAR(50), tp.transid)
			FROM #transid_tmp tp
			WHERE NOT EXISTS (SELECT TOP 1 1 FROM dbo.MarkedTransaction mt WITH(NOLOCK) WHERE mt.TransId = tp.transid)
			GROUP BY TransId for XML PATH('')), 1, 1, ''
			)
		IF @MarkedTransIds IS NOT NULL
		BEGIN
			SELECT @Username = (SELECT c.username FROM CustDB.dbo.Customer c WITH (NOLOCK) WHERE c.custid = @UserId)
			EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId
														, @MarkType = 1, @LogActionId = 90508
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
	ELSE IF @IssueTypeId = 1
	BEGIN
		IF @OldIsFilterByTransTime <> @IsFilterByTransTime
		BEGIN
			SET @LogDataContent += ' Old IsFilterByTransTime: ' + CAST(@OldIsFilterByTransTime AS VARCHAR(10))
								+ ' New IsFilterByTransTime: ' + CAST(@IsFilterByTransTime AS VARCHAR(10))
			IF @IsFilterByTransTime = 1 
			BEGIN
				SET @LogDataContent += ', From: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21) + ', To: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
			END
			ELSE
			BEGIN
				SET @LogDataContent += ', From: ' + CAST(@FilterFromBetId AS VARCHAR(20)) + ', To: ' + CAST(@FilterToBetId AS VARCHAR(20))
			END

		END
		IF @IsFilterByTransTime = 1 AND @OldFilterFromTransTime <> @FilterFromTransTime
		BEGIN
			SET @LogDataContent += ' Old From Transdate: ' + CONVERT(VARCHAR(30), @OldFilterFromTransTime, 21)
								+ ' New From Transdate: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21)
		END
		ELSE IF @IsFilterByTransTime = 1 AND @OldFilterToTransTime <> @FilterToTransTime
		BEGIN
			SET @LogDataContent += ' Old To Transdate: ' + CONVERT(VARCHAR(30), @OldFilterToTransTime, 21)
								+ ' New To Transdate: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
		END
		ELSE IF @IsFilterByTransTime = 0 AND @OldFilterFromBetId <> @FilterFromBetId
		BEGIN
			SET @LogDataContent += ' Old From BetID: ' + CAST(@OldFilterFromBetId AS VARCHAR(20))
									+ ' New From BetID: ' + CAST(@FilterFromBetId AS VARCHAR(20))
		END
		ELSE IF @IsFilterByTransTime = 0 AND @OldFilterToBetId <> @FilterToBetId
		BEGIN
			SET @LogDataContent += ' Old To BetID: ' + CAST(@OldFilterToBetId AS VARCHAR(20))
									+ ' New To BetID: ' + CAST(@FilterToBetId AS VARCHAR(20))
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
END
GO