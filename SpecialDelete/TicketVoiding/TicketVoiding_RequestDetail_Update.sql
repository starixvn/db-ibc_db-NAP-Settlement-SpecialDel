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
	IF @IssueTypeId = 11 AND (@Sporttype IN (1, 2, 9, 43, 5) OR @ActionId = 4)
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
			EXEC dbo.Nap_SpecialDelete_UnMarkedTickets_Update @TransIds = @MarkedTransIds, @UserId = @UserId, @Username = @Username, @IP = @IP, @RequestId = @RequestId, @MarkType = 1, @LogActionId = 90508
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