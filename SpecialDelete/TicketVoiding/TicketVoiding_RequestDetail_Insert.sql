/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Insert]
(
	@RequestId		INT
	,@MatchId		INT
	,@IssueTypeId	TINYINT		= NULL
	,@KickOffTime	DATETIME	= NULL
	,@TransIds VARCHAR(MAX) = NULL
	,@UserId		INT
	,@IP			VARCHAR(50)	= NULL
	,@ActionId		TINYINT
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

	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

			,@LeagueId			INT
			,@HomeId			INT
			,@AwayId			INT
			,@Sporttype 		SMALLINT

			,@MarkedTransIds	VARCHAR(MAX)
			,@Username			NVARCHAR(200)
			,@IsCalQueue	BIT = 0
			,@IsTransidProcessed BIT = 0			

	-- get match info
	SELECT	@LeagueId = leagueid
			,@HomeId = homeid
			,@AwayId = awayid
			,@Sporttype = sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchId

	--
	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT val 
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (maxrecursion 0)

	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, StatusId INT, statuswinlost TINYINT)
	INSERT INTO #transid_tmp (transid, bettype,StatusId, statuswinlost)
	SELECT t.transid, b.bettype, b.statusID, b.statuswinlost
	FROM #transIdTemp t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
	
	SET @IsCalQueue = ( SELECT TOP (1) 1
							FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
							WHERE StatusId IN (1,2,4) AND matchid = @MatchId AND RequestId = 0
							)
	
	IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE statusid = 0 AND statuswinlost IS NOT NULL)
		SET @IsTransidProcessed = 1
				
	SET @StartTime = GETDATE()
	SET @LogActionId = 90001
	SET @SB_Error = 0	

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
		, IsFilterByTransTime
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
		)
	SELECT @RequestId
		, @MatchId
		, @LeagueId
		, @HomeId
		, @AwayId
		, @KickOffTime
		, CASE WHEN @ActionId = 4 THEN 1 ELSE 0 END
		,@FilterFromTransTime
		,@FilterToTransTime
		,@FilterFromBetId
		,@FilterToBetId
		,@IsFilterByTransTime
		,@SingleCount
		,@MainParlayCount
		,@MinSingleTransId
		,@MaxSingleTransId
		,@MinMainParlayTransId
		,@MaxMainParlayTransId
		,@VoidFromTime
		,@VoidToTime
		,@LiveHomeScore
		,@LiveAwayScore

	-- Insert queue for auto void
	IF @IssueTypeId = 11 AND @Sporttype <= 99
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
		
		IF @ActionId = 4 OR (@ActionId = 1 AND @IsCalQueue = 1 AND @IsTransidProcessed = 1)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP, sporttype)
			VALUES(@RequestId, @MatchId, CASE WHEN @ActionId = 1 THEN 'AddRequest' ELSE 'VoidInstant' END, 0, 10278938, GETDATE(), '125.227.140.97', @Sporttype)
		END
	END
	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,@UserId AS '@UserId'							
							,@IP AS '@IP'						
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ (CASE
									WHEN @KickOffTime IS NOT NULL THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', KickOffTime: ' + CONVERT(VARCHAR(30), @KickOffTime, 21)
									WHEN @TransIds IS NOT NULL THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', TransIds: ' + @TransIds
									WHEN @IsFilterByTransTime = 1 THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', From: ' + CONVERT(VARCHAR(30), @FilterFromTransTime, 21) + ', To: ' + CONVERT(VARCHAR(30), @FilterToTransTime, 21)
									WHEN @IsFilterByTransTime = 0 THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', From: ' + CAST(@FilterFromBetId AS VARCHAR(20)) + ', To: ' + CAST(@FilterToBetId AS VARCHAR(20))
									ELSE ''
								END)
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
	
	DROP TABLE #transIdTemp
	DROP TABLE #transid_tmp
	
END
GO