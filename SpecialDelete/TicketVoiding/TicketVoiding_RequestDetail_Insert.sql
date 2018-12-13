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

	DECLARE @StartTime	DATETIME
			,@EndTime	DATETIME

			,@LeagueId	INT
			,@HomeId	INT
			,@AwayId	INT
			,@Sporttype SMALLINT

	SET @StartTime = GETDATE()

	SELECT	@LeagueId = leagueid
			,@HomeId = homeid
			,@AwayId = awayid
			,@Sporttype = sporttype
	FROM	dbo.match WITH(NOLOCK)
	WHERE	matchid = @MatchId

	INSERT INTO dbo.TicketVoiding_RequestDetail (RequestId, MatchId, LeagueId, HomeId, AwayId, KickOffTime)
	SELECT @RequestId, @MatchId, @LeagueId, @HomeId, @AwayId, @KickOffTime

END
GO