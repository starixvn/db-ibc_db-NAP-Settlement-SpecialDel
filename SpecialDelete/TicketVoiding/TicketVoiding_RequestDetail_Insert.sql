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
			--- param for autovoid queue
			,@IsTransidHT	BIT = 0
			,@IsTransidFT	BIT = 0
			,@IsTransidEAR	BIT = 0
			
			,@IsCalHTQueue	BIT = 0
			,@IsCalFTQueue	BIT = 0
			,@IsCalAllQueue	BIT = 0
			,@IsCalEarlyQueue	BIT = 0
			,@ActionID		INT = 0
			

	CREATE TABLE #transIdTemp (transid BIGINT PRIMARY KEY)
	INSERT INTO #transIdTemp (transid)
	SELECT DISTINCT val 
	FROM dbo.f_SplitString(@TransIds, ',')
	WHERE val <> ''
	OPTION (maxrecursion 0)

	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, groupid INT, StatusId INT)
	INSERT INTO #transid_tmp (transid, bettype,groupid,StatusId)
	SELECT t.transid, b.bettype, f.GroupId, b.statusID
	FROM #transIdTemp t
		INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
		INNER JOIN dbo.f_Set_GetGroupBettypes() f ON f.BetType = b.bettype
	
	IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE groupid IN (1,3))
		SET @IsTransidHT = 1
	
	IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE groupid IN (2,4))
		SET @IsTransidFT = 1

	IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp t
					INNER JOIN dbo.f_Set_GetEarlyBettypes() eb ON eb.bettype = t.bettype)
		SET @IsTransidEAR = 1
	
	SELECT @IsCalHTQueue = MAX(CASE WHEN Action = 'CAL-HT' THEN 1 ELSE 0 END)
			, @IsCalFTQueue =MAX( CASE WHEN Action = 'CAL-FT' THEN 1 ELSE 0 END)
			, @IsCalAllQueue = MAX(CASE WHEN Action = 'CAL' THEN 1 ELSE 0 END)
			, @IsCalEarlyQueue = MAX(CASE WHEN Action IN ('CAL-EAR', 'CAL-EARLY') THEN 1 ELSE 0 END)
	FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
	WHERE StatusId IN (1,2,4) AND matchid = @MatchId AND RequestId = 0
			
	SET @StartTime = GETDATE()
	SET @LogActionId = 90001
	SET @SB_Error = 0

	SELECT	@LeagueId = leagueid
			,@HomeId = homeid
			,@AwayId = awayid
			,@Sporttype = sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchId

	INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, KickOffTime, TransIds)
	SELECT @RequestId, @MatchId, @LeagueId, @HomeId, @AwayId, @KickOffTime, @TransIds

	-- Insert queue for auto void
	IF @IssueTypeId = 11 AND @Sporttype IN (1, 2, 9, 43)
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
															, @MarkType = 1
		END
	
		SELECT @ActionID = ( SELECT R.ActionId FROM dbo.TicketVoiding_Request r WITH (NOLOCK) WHERE r.RequestId = @RequestId)
		IF @ActionID = 1 AND (
				(@IsCalHTQueue = 1 AND  @IsTransidHT = 1)
			OR  (@IsCalFTQueue = 1 AND  (@IsTransidFT = 1 OR @IsTransidHT = 1))
			OR	(@IsCalAllQueue = 1 AND (@IsTransidFT = 1 OR @IsTransidHT = 1))
			OR	(@IsCalEarlyQueue = 1 AND (@IsTransidEAR = 1))
			)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP)
			VALUES(@RequestId, @MatchId, 'AddRequest', 0, 10278938, GETDATE(), '125.227.140.97')
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