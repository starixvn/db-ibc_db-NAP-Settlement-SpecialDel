/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
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
		- 20230103@Kathy: Support ON bit 1 & 5 for other sport [Redmine:#181458]    
		- 20230921@Aries: Allow to Change Auto Settle Setting for Completed Matches [Redmine:#194117]  
		- 20231002@Aries: Apply Auto Payout for Cricket by using TheSports Provider  [Redmine: #195768]
		- 20240125@Aries: Tennis - Don't turn off AUTO setting when change setting to DIRECT & vice versa on Match  [Redmine: #200259]
		- 20240110@Louisa: Allow update Auto Payout when match completed [Redmine:#198710]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]
		- 20240305@Aries: Direct Payout for the Fantasy Match of Basketball [Redmine:#199768]
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
		
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
		, @Remark 				VARCHAR(1024)
		, @LeagueId 			INT
		, @Sporttype			SMALLINT
		, @HasAP2				BIT = 0
	/*
	SELECT	@actionLogId = CASE 
									WHEN @AutoType = 1 THEN 160
									WHEN @AutoType = 2 THEN 181
									WHEN @AutoType = 3 THEN 184
									WHEN @AutoType = 4 THEN 81007
									WHEN @AutoType = 5 THEN 160
									ELSE -1 
								END
	*/
	SELECT	@AutoSetting = AutoSetting
			,@LeagueId = leagueid
			,@Sporttype = sporttype
	FROM	dbo.match m WITH(NOLOCK)
	WHERE	m.matchid = @MatchId

	SELECT @HasAP2 = IIF(AP_Group IS NOT NULL OR Setting & 8 = 8,1,0)
	FROM SettlementResultTableSetting WITH(NOLOCK) 
	WHERE sporttype = @Sporttype
	
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
	IF @Sporttype = 1 OR @HasAP2 = 1
		SELECT @AutoSetting =
								CASE WHEN @AutoType IN (1, 5) THEN 
																CASE WHEN @AutoType = 1 THEN IIF(@IsEnabled = 1,@AutoSetting & (238 + POWER(2,@AutoType - 1)),@AutoSetting & 238)
																	 WHEN @AutoType = 5 THEN IIF(@IsEnabled = 1,@AutoSetting & (206 + POWER(2,@AutoType - 1)),@AutoSetting & 206)
																	 WHEN @AutoType = 6	THEN IIF(@IsEnabled = 1,@AutoSetting & (207 + POWER(2,@AutoType - 1)),@AutoSetting & 207)		 			
																	 ELSE @AutoSetting & 206
																END
									ELSE @AutoSetting 
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
END
GO