/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_WaitingTimeLeagueUpd]
	@LeagueId			INT
	,@AutoType			TINYINT
	,@WaitingTime		INT
	,@AdminId			INT
	,@ErrCode 			INT				= 0		OUTPUT
	,@ErrMsg 			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20180806@Kathy
	Task: Update waiting time for league
	DB: DBPRO/BODB02
	
	Revisions:
		- 20180806@Kathy: Update waiting time for auto instant [Redmine:#86964]
		- 20240621@Aries: Enhance Auto Refund to add waiting time [Redmine:#206153]
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
		
	Param's Explanation:
		- @AutoType: TINYINT 
			+ 1: Auto Payout
			+ 2: Inst Calculation
			+ 3: Fast Market
			+ 7: Auto Refund
		- @WaitingTime: in second
 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @StartTime DATETIME
			,@EndTime DATETIME
			,@Remark VARCHAR(300)
			,@OldWaitingTime INT

	SET @StartTime = GETDATE()

	SELECT	@OldWaitingTime = WaitingTime
	FROM	dbo.SettlementSetting WITH(NOLOCK)
	WHERE	LeagueId = @LeagueId
			AND AutoType = @AutoType

	IF @@ROWCOUNT = 0
	BEGIN
		INSERT INTO dbo.SettlementSetting (LeagueId, AutoType, WaitingTime)
		SELECT @LeagueId, @AutoType, @WaitingTime
	END
	ELSE
	BEGIN
		UPDATE	dbo.SettlementSetting
			SET WaitingTime = @WaitingTime
		WHERE	LeagueId = @LeagueId
				AND AutoType = @AutoType
	END

	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1001020
				,@ErrMsg = 'Cannot update wating time setting on this league. Please try again.'
	END
	
	SET @EndTime = GETDATE()

	SET @Remark = 'Update waiting time setting on leagueid: ' + CAST(@LeagueId AS VARCHAR) 
					+ CASE WHEN @AutoType = 2 THEN ' for Auto Instant' ELSE '' END
					+ CASE WHEN @AutoType = 7 THEN ' for Auto Refund' ELSE '' END
					+ CASE WHEN @OldWaitingTime IS NOT NULL THEN '. Old waiting time: ' + CAST(@OldWaitingTime AS VARCHAR) + ' seconds' ELSE '' END
					+ '. New waiting time: ' + CAST(@WaitingTime AS VARCHAR) + ' seconds'
					+ '. Duration: ' + CAST(DATEDIFF(MILLISECOND, @StartTime, @EndTime) AS VARCHAR) + ' ms'

END
GO