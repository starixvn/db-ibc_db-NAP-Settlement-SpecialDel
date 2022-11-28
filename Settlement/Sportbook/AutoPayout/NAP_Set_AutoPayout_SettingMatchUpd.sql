/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_AutoPayout_SettingMatchUpd 
	@MatchId 			INT
	, @AutoType			TINYINT
	, @IsEnabled		BIT 
	, @AdminId 			INT
	, @IP 				VARCHAR(20) = ''
	, @ErrCode 			INT = 0 OUTPUT
	, @ErrMsg 			NVARCHAR(200) = '' OUTPUT
AS
/*	Creator: 20160303@Patrick
	Task: Auto Payout - update setting on match
	DB: DBPRO/BODB02
	
	Revisions:
		- 20160930@Bobby: #65003 - Merge Auto Payout and Inst CAL setting
		- 20161212@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170123@Kathy: Allow user to Enable/Disable Auto Settlement of Fast Market [Redmine:#69949]
		- 20180801@Kathy: delete all scores haven't been confirmed yet in ProviderResultDetail when off setting [Redmine:#86964]
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200225@Sol: Direct Settlement Action for Soccer - [Redmine:#103568]
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
		- 20221128@Louisa: Do not check match.eventstatus when turn on/off Instant setting [Redmine:#180939]
		
	Param's Explanation:
		- @AutoType: TINYINT 
			+ 1: Auto Payout
			+ 2: Inst Calculation
			+ 3: Fast Market
			+ 4: BetBuilder
			+ 5: Auto Payout - Direct
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @AutoSetting 		TINYINT
		, @StarTime 			DATETIME
		, @EndTime 				DATETIME
		, @Remark 				VARCHAR(1024)
		, @LeagueId 			INT
		, @actionLogId			INT
	
	SELECT	@StarTime 			= GETDATE()
			,@actionLogId = CASE 
									WHEN @AutoType = 1 THEN 160
									WHEN @AutoType = 2 THEN 181
									WHEN @AutoType = 3 THEN 184
									WHEN @AutoType = 4 THEN 81007
									WHEN @AutoType = 5 THEN 160
									ELSE -1 
								END
	
	SELECT	@AutoSetting = AutoSetting
			,@LeagueId = leagueid
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId
	
	IF @AutoSetting IS NULL
	BEGIN
		SELECT @AutoSetting = ISNULL(AutoSetting, 0)
		FROM dbo.League l WITH(NOLOCK)
		WHERE LeagueId = @LeagueId
	END
	
	SELECT	@AutoSetting =  CASE 
								WHEN @IsEnabled = 1 THEN @AutoSetting | POWER(2,@AutoType - 1) 
								ELSE CASE WHEN @AutoSetting >= (POWER(2,@AutoType - 1)) THEN @AutoSetting ^ (POWER(2,@AutoType - 1))  ELSE @AutoSetting END
							END

	-- turn off bit 1 or 5
	SELECT @AutoSetting =
							CASE WHEN @AutoType IN (1, 5) THEN 
																CASE WHEN @IsEnabled = 1 THEN @AutoSetting & (238 + POWER(2,@AutoType - 1)) 
																	ELSE @AutoSetting & 238
																END
								ELSE @AutoSetting 
							END

	--check match <> running
	IF EXISTS (
		SELECT TOP 1 1 
		FROM dbo.match m WITH(NOLOCK) 
		WHERE matchid = @MatchId 
			AND 1 = CASE 
					WHEN @AutoType IN (1, 5) AND eventstatus = 'completed' THEN 1
					ELSE 0 
				END
	)
	BEGIN
		SELECT @ErrCode = 1001023, @ErrMsg = 'Sorry. Not allow to update auto Setting on this match.'
		RETURN
	END

	UPDATE m
	SET AutoSetting = @AutoSetting
	FROM dbo.match m WITH(UPDLOCK, ROWLOCK)
	WHERE m.matchid = @MatchId

	IF @@ERROR > 0
	BEGIN
		SELECT @ErrCode = 1001019, @ErrMsg = 'Cannot update auto setting on this match. Please try again.'
		RETURN
	END
	
	IF @IsEnabled = 0 AND @AutoType = 2
	BEGIN
		DELETE
		FROM 	dbo.ProviderResultDetail
		WHERE	matchid = @matchid
				AND IsConfirmed = 0
				AND SourceId = 100
	END 

	SELECT @EndTime = GETDATE()
	SELECT @Remark = 'NAP: Update auto setting on match:' + CAST(@MatchId AS NVARCHAR(10)) 
		+ ' AutoSetting:' + CAST(ISNULL(@AutoSetting, 0) AS NVARCHAR(10))
		+ ' AutoType:' + CAST(ISNULL(@AutoType, 0) AS NVARCHAR(10))
		+ ' Duration:' + CAST(DATEDIFF(MILLISECOND, @StarTime, @EndTime) AS NVARCHAR(50)) + ' ms'

	BEGIN TRY
		EXEC DBLOG.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			, @Matchid			= @MatchId
			, @ActionID			= @actionLogId
			, @finalhomescore	= NULL
			, @finalawayscore	= NULL
			, @hthomescore		= NULL
			, @htawayscore		= NULL
			, @GoalRecord		= NULL
			, @betstatus		= NULL
			, @Remark			= @Remark
			, @IP				= @IP
	END TRY

	BEGIN CATCH
		SELECT @Remark = @Remark + ' ErrMsg=' + LEFT(ERROR_MESSAGE(), 250)

		EXEC DBTXN.bodb_CustomerLog.dbo.WriteLog_UserLog_Settle @UserID = @AdminId
			, @Matchid			= @MatchId
			, @ActionID			= @actionLogId
			, @finalhomescore	= NULL
			, @finalawayscore	= NULL
			, @hthomescore		= NULL
			, @htawayscore		= NULL
			, @GoalRecord		= NULL
			, @betstatus		= NULL
			, @Remark			= @Remark
			, @IP				= @IP
	END CATCH 

END
GO