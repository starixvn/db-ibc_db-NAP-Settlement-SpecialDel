/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_SettingLeagueUpd] 
	@LeagueId 			INT
	, @AutoType			TINYINT
	, @IsEnabled		BIT 
	, @IsApplyAll 		BIT
	, @AdminId 			INT
	, @IP 				VARCHAR(20) = ''
	, @UpdatedMatchIDs	VARCHAR(MAX)=''		OUTPUT
	, @ErrCode 			INT = 0 			OUTPUT
	, @ErrMsg 			NVARCHAR(200) = '' 	OUTPUT
AS
/*	Creator: 20160303@Patrick
	Task: Auto Payout - update setting on league
	DB: DBPRO/BODB02
	
	Revisions:
		- 20160930@Bobby: #65003 - Merge Auto Payout and Inst CAL setting
		- 20161212@Bobby: #67760 - Implement IS for FGLG bet types
		- 20170123@Kathy: Allow user to Enable/Disable Auto Settlement of Fast Market [Redmine:#69949]
		- 20180801@Kathy: delete all scores haven't been confirmed yet in ProviderResultDetail when off setting [Redmine:#86964]
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200225@Sol: Direct Settlement Action for Soccer - [Redmine:#103568]
		- 20200817@July: Add sporttype = 2 (BetBuilder BasketBall) - [Redmine:#138475]
		- 20210311@Max: Auto Payout for Table Tennis [Redmine: #143442]
		- 20230103@Kathy: Support ON bit 1 & 5 for other sport [Redmine:#181458]
		- 20231002@Aries: Apply Auto Payout for Cricket by using TheSports Provider  [Redmine: #195768]
		- 20240108@Aries: Don't update the same setting for league & corresponding running match  [Redmine: #199495]
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		- 20240229@Aries: Auto Payout for e-Sports Main ＆ Early Results  [Redmine: #191875]
		- 20240305@Aries: Direct Payout for the Fantasy Match of Basketball [Redmine:#199768]
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]

	Param's Explanation:
		- @IsApplyAll: 0: only update on league
					   1: update on league & running match without matches in Queue
					   
		- @AutoType: TINYINT 
			+ 1: Auto Payout 1/ Auto Payout 2 - Main
			+ 2: Inst Calculation
			+ 3: Fast Market
			+ 4: BetBuilder
			+ 5: Auto Payout - Direct
			+ 6: Auto Payout 2 - Early
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @AutoSettingForLeague 		TINYINT
		, @AutoSetting					TINYINT
		, @Sporttype					SMALLINT
		, @HasAP2						BIT = 0
		
	DECLARE @tmpUpdatedMatches TABLE (matchid INT)
		
	SET @UpdatedMatchIDs = ''
			
	SELECT @AutoSettingForLeague = ISNULL(AutoSetting, 0)
			,@Sporttype = sporttype
	FROM	dbo.League l WITH(NOLOCK) 
	WHERE	leagueid = @LeagueId

	SELECT @HasAP2 = IIF(AP_Group IS NOT NULL OR Setting & 8 = 8,1,0)
	FROM SettlementResultTableSetting WITH(NOLOCK) 
	WHERE sporttype = @Sporttype

	/*  Web call write log
	SELECT @actionLogId = CASE WHEN @AutoType = 1 AND @HasAP2 = 0 THEN 159 
							   WHEN @AutoType = 1 AND @HasAP2 = 1 THEN 81055 
							   WHEN @AutoType = 2 THEN 180
							   WHEN @AutoType = 3 THEN 183
							   WHEN @AutoType = 4 THEN 81006
							   WHEN @AutoType = 5 THEN 159
							   WHEN @AutoType = 6 THEN 81056
							   ELSE -1 
						  END
	*/

	-- update setting for matches do not have any setting
	UPDATE	m
		SET AutoSetting = @AutoSettingForLeague
	FROM	dbo.match m WITH(UPDLOCK, ROWLOCK)
	WHERE	m.leagueid = @LeagueId 
			AND AutoSetting IS NULL
	
	SELECT	@AutoSettingForLeague =  CASE 
										WHEN @IsEnabled = 1 THEN @AutoSettingForLeague | POWER(2,@AutoType - 1) 
										ELSE CASE WHEN @AutoSettingForLeague >= (POWER(2,@AutoType - 1)) THEN @AutoSettingForLeague ^ (POWER(2,@AutoType - 1))  ELSE @AutoSettingForLeague END
									END
	
	-- turn off bit 1 or 5
	IF @Sporttype = 1 OR @HasAP2 = 1
		SELECT @AutoSettingForLeague =
								CASE WHEN @AutoType = 1 THEN IIF(@IsEnabled = 1,@AutoSettingForLeague & (238 + POWER(2,@AutoType - 1)),@AutoSettingForLeague & 238)
									 WHEN @AutoType = 5 THEN IIF(@IsEnabled = 1,@AutoSettingForLeague & (206 + POWER(2,@AutoType - 1)),@AutoSettingForLeague & 206)
									 WHEN @AutoType = 6	THEN IIF(@IsEnabled = 1,@AutoSettingForLeague & (207 + POWER(2,@AutoType - 1)),@AutoSettingForLeague & 207)		 			
									 ELSE @AutoSettingForLeague & 206
								END

	--update setting on league
	UPDATE	dbo.League WITH(ROWLOCK, UPDLOCK)
		SET AutoSetting = @AutoSettingForLeague
	WHERE	leagueid = @LeagueId

	IF @@ERROR > 0
	BEGIN
		SELECT	@ErrCode = 1001018
				,@ErrMsg = 'Cannot update auto setting on this league. Please try again.'
				
		RETURN
	END
								
	IF @IsApplyAll = 1
	BEGIN
		--update running match and turn off bit 1 or 5
		UPDATE m
			SET @AutoSetting = ISNULL(m.AutoSetting,0)
				,@AutoSetting = CASE 
									WHEN @IsEnabled = 1 THEN @AutoSetting | POWER(2,@AutoType - 1) 
									ELSE CASE WHEN @AutoSetting & (POWER(2,@AutoType - 1)) = 0 THEN @AutoSetting ELSE @AutoSetting ^ (POWER(2,@AutoType - 1)) END
								END
				,@AutoSetting = CASE WHEN (@Sporttype = 1 OR @HasAP2 = 1) AND @AutoType IN (1, 5,6) THEN 
																CASE WHEN @AutoType = 1 THEN IIF(@IsEnabled = 1,@AutoSettingForLeague & (238 + POWER(2,@AutoType - 1)),@AutoSettingForLeague & 238)
																	 WHEN @AutoType = 5 THEN IIF(@IsEnabled = 1,@AutoSettingForLeague & (206 + POWER(2,@AutoType - 1)),@AutoSettingForLeague & 206)
																	 WHEN @AutoType = 6	THEN IIF(@IsEnabled = 1,@AutoSettingForLeague & (207 + POWER(2,@AutoType - 1)),@AutoSettingForLeague & 207)		 			
																	 ELSE @AutoSetting & 206
																END
								ELSE @AutoSetting 
							END
				,AutoSetting = @AutoSetting
		OUTPUT  deleted.matchid INTO @tmpUpdatedMatches (matchid)
		FROM	dbo.match m WITH(UPDLOCK, ROWLOCK)
		WHERE	m.leagueid 	= @LeagueId 
				AND 1 = CASE 
							WHEN @AutoType IN (1,3,5,6) AND eventstatus <> 'completed' THEN 1
							WHEN @AutoType = 2 AND eventstatus IN ('running', 'closed') THEN 1
							WHEN @AutoType = 4 THEN 1
							ELSE 0 
						END
		
		IF @@ERROR > 0
		BEGIN
			SELECT @ErrCode = 1001019, @ErrMsg = 'Cannot update auto setting on match. Please try again.'
			RETURN
		END
		
		IF @AutoType = 2 AND @IsEnabled = 0
		BEGIN
			DELETE p
			FROM	dbo.ProviderResultDetail p
				INNER JOIN @tmpUpdatedMatches m
					ON p.matchid = m.matchid
			WHERE	p.IsConfirmed = 0
					AND p.SourceId = 100
					
		END
		
	END

	--RETURN DATA
	SELECT @UpdatedMatchIDs =  CAST(matchID AS VARCHAR) + ',' + @UpdatedMatchIDs
	FROM @tmpUpdatedMatches

END

GO