/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_LeagueSetting_Update]
	 @LeagueId						INT
	,@AutoType						TINYINT			= 6

	,@Main_WaitingTime				INT				= NULL
	,@Main_HasTrader				BIT				= NULL
	,@Main_NumberProvider			TINYINT			= NULL
	,@Main_PrimaryProvider			VARCHAR(500)	= NULL
	,@Main_TotalPrimaryProvider		TINYINT			= NULL
	,@Main_SecondaryProvider		VARCHAR(500)	= NULL
	,@Main_TotalSecondaryProvider	TINYINT			= NULL
	,@Main_InactiveProvider			VARCHAR(500)	= NULL
													
	,@EAR_WaitingTime				INT				= NULL
	,@EAR_HasTrader					BIT				= NULL
	,@EAR_NumberProvider			TINYINT			= NULL
	,@EAR_PrimaryProvider			VARCHAR(500)	= NULL
	,@EAR_TotalPrimaryProvider		TINYINT			= NULL
	,@EAR_SecondaryProvider			VARCHAR(500)	= NULL
	,@EAR_TotalSecondaryProvider	TINYINT			= NULL
	,@Action						VARCHAR(20)		= 'Update'
	,@EAR_InactiveProvider			VARCHAR(500)	= NULL

	,@Enable						BIT				= NULL
	,@IsApplyAll 					BIT				= 0

	,@UpdatedMatchIDs				VARCHAR(MAX)=''		OUTPUT
AS
/*	Creator: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider
	DB: DBPRO/BODB02
	
	Revisions:
		- 20231211@Aries: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
		- 20241002@Aries: Support a tool to add leagues for Direct Payout [Redmine:#211265]
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
		- 20241223@Aries: Support Auto Refund for Soccer's Early Results [Redmine:#214410]
		
	Param's Explanation:
		- @AutoType: TINYINT 
			+ 1: Auto Payout
			+ 2: Inst Calculation
			+ 3: Fast Market
			+ 5: Direct Payout
			+ 6: Auto Payout Model 2
			+ 7: Auto Refund
			+ 8: HardCode Direct Soccer
			+ 9. HardCode Fantasy Soccer
			+ 10. HardCode Fantasy Basketball
		- @RetryTime: in second
		- @Action: Update or Delete
 
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @tmpUpdatedMatches TABLE (matchid INT)

	IF @Action = 'Delete'
	BEGIN
		DELETE
		FROM dbo.SettlementSetting
		WHERE LeagueId = @LeagueId
				AND AutoType = @AutoType

		RETURN
	END

	IF NOT EXISTS (SELECT 1 FROM	dbo.SettlementSetting WITH(NOLOCK) WHERE LeagueId = @LeagueId AND AutoType = @AutoType)
	BEGIN
		INSERT INTO dbo.SettlementSetting (LeagueId, AutoType
											
										  ,Main_HasTrader,Main_NumberProvider,WaitingTime
										  ,Main_PrimaryProvider,Main_TotalPrimaryProvider,Main_SecondaryProvider,Main_TotalSecondaryProvider
										  ,Main_InactiveProvider

										  ,EAR_HasTrader,EAR_NumberProvider,EAR_WaitingTime
										  ,EAR_PrimaryProvider,EAR_TotalPrimaryProvider,EAR_SecondaryProvider,EAR_TotalSecondaryProvider
										  ,EAR_InactiveProvider
										  
										  ,[Enable])
		SELECT @LeagueId, @AutoType

		      ,@Main_HasTrader,@Main_NumberProvider,@Main_WaitingTime
			  ,@Main_PrimaryProvider,@Main_TotalPrimaryProvider, @Main_SecondaryProvider,@Main_TotalSecondaryProvider
			  ,@Main_InactiveProvider

			  ,@EAR_HasTrader,@EAR_NumberProvider,@EAR_WaitingTime
			  ,@EAR_PrimaryProvider,@EAR_TotalPrimaryProvider,@EAR_SecondaryProvider,@EAR_TotalSecondaryProvider
			  ,@EAR_InactiveProvider

			  ,@Enable
	END
	ELSE
	BEGIN
		UPDATE	dbo.SettlementSetting
			SET  WaitingTime					= ISNULL(@Main_WaitingTime,WaitingTime)

				,Main_HasTrader					= ISNULL(@Main_HasTrader,Main_HasTrader)
				,Main_NumberProvider			= ISNULL(@Main_NumberProvider,Main_NumberProvider)
												  
				,Main_PrimaryProvider			= ISNULL(@Main_PrimaryProvider,Main_PrimaryProvider)
				,Main_TotalPrimaryProvider		= ISNULL(@Main_TotalPrimaryProvider,Main_TotalPrimaryProvider)
				,Main_SecondaryProvider			= ISNULL(@Main_SecondaryProvider,Main_SecondaryProvider)
				,Main_TotalSecondaryProvider	= ISNULL(@Main_TotalSecondaryProvider,Main_TotalSecondaryProvider)
				,Main_InactiveProvider			= ISNULL(@Main_InactiveProvider,Main_InactiveProvider)
		
				,EAR_WaitingTime				= ISNULL(@EAR_WaitingTime,EAR_WaitingTime)
				,EAR_HasTrader					= ISNULL(@EAR_HasTrader,EAR_HasTrader)
				,EAR_NumberProvider				= ISNULL(@EAR_NumberProvider,EAR_NumberProvider)
												 
				,EAR_PrimaryProvider			= ISNULL(@EAR_PrimaryProvider,EAR_PrimaryProvider)	
				,EAR_TotalPrimaryProvider		= ISNULL(@EAR_TotalPrimaryProvider,EAR_TotalPrimaryProvider)
				,EAR_SecondaryProvider			= ISNULL(@EAR_SecondaryProvider,EAR_SecondaryProvider)
				,EAR_TotalSecondaryProvider		= ISNULL(@EAR_TotalSecondaryProvider,EAR_TotalSecondaryProvider)
				,EAR_InactiveProvider			= ISNULL(@EAR_InactiveProvider,EAR_InactiveProvider)

				,[Enable]						= ISNULL(@Enable,[Enable])
		WHERE	LeagueId = @LeagueId
				AND AutoType = @AutoType
	END

	IF @IsApplyAll = 1 AND @AutoType = 7
	BEGIN
		INSERT INTO @tmpUpdatedMatches(MatchId)
		SELECT ms.MatchId
		FROM dbo.AutoPayoutSetting AS ms WITH(NOLOCK)  
			INNER JOIN match AS m WITH(NOLOCK)  ON ms.matchid = m.matchid
		WHERE m.leagueID = @LeagueId
			AND ms.AutoType = 7
			AND ISNULL(ms.[Enable],0) != @Enable
			AND m.eventstatus =  'running'

		UPDATE ms
		SET ms.[Enable] = @Enable
		FROM dbo.AutoPayoutSetting  AS ms WITH(UPDLOCK, ROWLOCK)
		WHERE ms.matchid IN (SELECT um.matchid FROM @tmpUpdatedMatches as um)

		SELECT @UpdatedMatchIDs =  CAST(matchID AS VARCHAR) + ',' + @UpdatedMatchIDs
		FROM @tmpUpdatedMatches
	END


END
GO