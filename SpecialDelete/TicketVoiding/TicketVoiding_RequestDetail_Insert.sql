/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_RequestDetail_Insert]
	@RequestId		INT
	,@MatchId		INT
	,@KickOffTime	DATETIME		= NULL
	
AS
/*	Created by: Kathy
	Date 20181212
	Task: insert request detail [Redmine:#90155]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181212@Kathy: Create new SP [Redmine:#90155]
	
	Param's explanation:	
	
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @StartTime			DATETIME
			,@EndTime			DATETIME
			,@LogActionId		INT
			,@LogData			VARCHAR(MAX)
			,@SB_Error			BIT

			,@LeagueId	INT
			,@HomeId	INT
			,@AwayId	INT
			,@Sporttype SMALLINT
	
	SET @StartTime = GETDATE()
	SET @LogActionId = 90000
	SET @SB_Error = 0

	SELECT	@LeagueId = leagueid
			,@HomeId = homeid
			,@AwayId = awayid
			,@Sporttype = sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchId

	INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, KickOffTime)
	SELECT @RequestId, @MatchId, @LeagueId, @HomeId, @AwayId, @KickOffTime

	-- Write Log
	SET @EndTime = GETDATE()
	SET @LogData = CAST((SELECT	@RequestId AS '@RequestId'
							,@LogActionId AS '@LogActionId'
							,'Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR(50)) + ' ms.' 
								+ CASE WHEN @KickOffTime IS NOT NULL THEN ' MatchId: ' + CAST(@MatchId AS VARCHAR(20)) + ', KickOffTime: ' + CAST(@KickOffTime AS VARCHAR(30)) ELSE '' END
								AS '@LogData'
					FOR XML PATH ('r'), ROOT ('root'), TYPE
	) AS VARCHAR(MAX))

	EXEC bodb_CustomerLog.sb.CustomerLog_SendMessage @xml = @LogData, @functionName = 'TicketVoiding', @MessageType = 'MessageType_TicketVoiding_Log', @SB_error = @SB_error OUTPUT
END
GO