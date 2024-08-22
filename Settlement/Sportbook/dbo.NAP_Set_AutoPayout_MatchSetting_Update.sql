/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_AutoPayout_MatchSetting_Update]
	 @MatchId						INT
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
	,@EAR_InactiveProvider			VARCHAR(500)	= NULL
AS
/*	Creator: 20231211@Aries
	Task: Enhance AutoPayout2 to support Direct Payout 
	DB: DBPRO/BODB02
	
	Revisions:
		- 20240822@Aries: Enhance AutoPayout2 to support Direct Payout [Redmine:#209415]
		
	Param's Explanation:
		- @AutoType: TINYINT 
			+ 6: Auto Payout Model 2
		- @WaitingTime: in second
 
*/
BEGIN
	SET NOCOUNT ON

	IF NOT EXISTS (SELECT 1 FROM dbo.AutoPayoutSetting WITH(NOLOCK) WHERE MatchId = @MatchId AND AutoType = @AutoType)
	BEGIN
		INSERT INTO dbo.AutoPayoutSetting (MatchId, AutoType
											
										  ,Main_HasTrader,Main_NumberProvider,WaitingTime
										  ,Main_PrimaryProvider,Main_TotalPrimaryProvider,Main_SecondaryProvider,Main_TotalSecondaryProvider
										  ,Main_InactiveProvider

										  ,EAR_HasTrader,EAR_NumberProvider,EAR_WaitingTime
										  ,EAR_PrimaryProvider,EAR_TotalPrimaryProvider,EAR_SecondaryProvider,EAR_TotalSecondaryProvider
										  ,EAR_InactiveProvider
										  
										  ,RepUpdateTime)
		SELECT @MatchId, @AutoType

		      ,@Main_HasTrader,@Main_NumberProvider,@Main_WaitingTime
			  ,@Main_PrimaryProvider,@Main_TotalPrimaryProvider, @Main_SecondaryProvider,@Main_TotalSecondaryProvider
			  ,@Main_InactiveProvider

			  ,@EAR_HasTrader,@EAR_NumberProvider,@EAR_WaitingTime
			  ,@EAR_PrimaryProvider,@EAR_TotalPrimaryProvider,@EAR_SecondaryProvider,@EAR_TotalSecondaryProvider
			  ,@EAR_InactiveProvider

			  ,SYSDATETIME()
	END
	ELSE
	BEGIN
		UPDATE	dbo.AutoPayoutSetting
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

				,RepUpdateTime					= SYSDATETIME()
		WHERE	MatchId = @MatchId
				AND AutoType = @AutoType
	END
END
GO