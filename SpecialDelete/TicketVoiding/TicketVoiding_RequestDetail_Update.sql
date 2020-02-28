/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Update]
(
	@RequestId		INT
	,@MatchId		INT
	,@KickOffTime	DATETIME	 = NULL

	,@UserId		INT
	,@IP			VARCHAR(50)	 = NULL
	,@TransIds 		VARCHAR(MAX) = NULL
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
			
			,@IssueTypeId		INT
			,@LeagueId			INT = NULL
			,@HomeId			INT = NULL
			,@AwayId			INT = NULL
			,@Sporttype			SMALLINT = NULL
			,@OldMatchId			INT
			,@OldTransIds 		VARCHAR(MAX) = NULL
			,@MarkedTransIds	VARCHAR(MAX)
			,@Username			NVARCHAR(200)
			--- param for autovoid queue
			,@IsTransidHT	BIT = 0
			,@IsTransidFT	BIT = 0
			
			,@IsCalHTQueue	BIT = 0
			,@IsCalFTQueue	BIT = 0
			,@IsCalAllQueue	BIT = 0
			,@ActionID		INT = 0

	CREATE TABLE #inputTransid (transid BIGINT)
	CREATE TABLE #transid_tmp (transid BIGINT, bettype SMALLINT, groupid INT, StatusId INT)

	SET @StartTime = GETDATE()
	SET @LogActionId = 90003
	SET @SB_Error = 0

	SELECT @IssueTypeId = tr.IssueTypeId
		,@ActionID = tr.ActionId
	FROM TicketVoiding_Request tr WITH (NOLOCK)
	WHERE tr.RequestId = @RequestId
	
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
				,TransIds = ISNULL(@TransIds, TransIds)

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
	IF @IssueTypeId = 11 AND @Sporttype IN (1, 2, 9, 43)
	BEGIN
		
		INSERT INTO #inputTransid (transid)
		SELECT DISTINCT val 
		FROM dbo.f_SplitString(@TransIds, ',')
		WHERE val <> ''
		OPTION (maxrecursion 0)

		INSERT INTO #transid_tmp (transid, bettype, groupid, StatusId)
		SELECT t.transid, b.bettype, f.GroupId, b.statusID
		FROM #inputTransid t
			INNER JOIN dbo.bettrans b WITH (NOLOCK) ON t.transid = b.transid
			INNER JOIN dbo.f_Set_GetGroupBettypes() f ON f.BetType = b.bettype
		WHERE b.statusID IN (0, 1)

		IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE groupid IN (1,3))
		SET @IsTransidHT = 1
	
		IF EXISTS (SELECT TOP (1) 1 FROM #transid_tmp WHERE groupid IN (2,4))
			SET @IsTransidFT = 1
	
		SELECT @IsCalHTQueue = MAX(CASE WHEN Action = 'CAL-HT' THEN 1 ELSE 0 END)
				, @IsCalFTQueue =MAX( CASE WHEN Action = 'CAL-FT' THEN 1 ELSE 0 END)
				, @IsCalAllQueue = MAX(CASE WHEN Action = 'CAL' THEN 1 ELSE 0 END)
		FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (NOLOCK)
		WHERE StatusId IN (1,2,4) AND matchid = @MatchId AND RequestId = 0

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
			EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = '125.227.140.97', @RequestId = @RequestId, @MarkType = 1
		END

		IF @ActionID = 1 AND (
				(@IsCalHTQueue = 1 AND  @IsTransidHT = 1)
			OR  (@IsCalFTQueue = 1 AND  (@IsTransidFT = 1 OR @IsTransidHT = 1))
			OR	(@IsCalAllQueue = 1 AND (@IsTransidFT = 1 OR @IsTransidHT = 1))
			)
		BEGIN
			INSERT INTO dbo.TicketVoiding_AutoVoidRequest_Queue(RequestId, MatchId, [Action], StatusId, UserId, Starttime, IP)
			VALUES(@RequestId, @MatchId, 'AddRequest', 0, 10278938, GETDATE(), '125.227.140.97')
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