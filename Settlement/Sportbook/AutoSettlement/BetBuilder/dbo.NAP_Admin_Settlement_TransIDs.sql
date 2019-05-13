/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_TransIDs]
	@TransIDs				VARCHAR(MAX)	
	,@Action				VARCHAR(50)
	,@ActionID				INT
	,@balanceCount 			INT				= 0		OUTPUT
	,@balanceCountChanged 	INT				= 0		OUTPUT
	,@ErrCode				INT				= 0		OUTPUT
	,@ErrMsg				NVARCHAR(200)	= ''	OUTPUT
	
AS
/*	Creator: Vicky
	Date: 20181228
	Task: BetBuilder Auto/Manual Settlement
	DB: DBTXN/BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		
	Param's Explanation:

		@Resources = '<root>
						<r t="104730774034" m="1"/>
						<r t="104729373985" m="0" ot="1"/>
					 </root>'
					 t:  transid
					 m:  modds
					 ot: oddstype: 1: DECIMAL ONLY
*/	
BEGIN
	SET NOCOUNT ON
	
	--START Balance tables
	DECLARE @BalanceWalletBefore		TVP_BalanceWalletChange
		   , @BalanceWalletAfter		TVP_BalanceWalletChange
	--END Balance tables
	
	
	----------------------------------------------------------------------
	SELECT @balanceCount = 0,@balanceCountChanged = 0
	
	
	BEGIN TRY
		INSERT INTO @BalanceWalletBefore (matchID, custID, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
						@MatchID 				  = 0
						,@sportType				  = 0
						,@Action 				  = @Action
						,@Mode 					  = 2
						,@TransIDs				  = @TransIDs
		SELECT @balanceCount = @@ROWCOUNT
	
		--------- UPDATE BETTRANS-----------------------------------------------
	    EXEC dbo.NAP_Admin_Calculate_Main
						@matchid	  		 = 0
					   ,@action				 = @Action
					   ,@IsSettingByProfile  = 1
					   ,@strTransIds		 = @TransIDs

		------END UPDATE BETTRANS-----------------------------------------------
		
		   
		-------------------------------------------------------------
		---		 CAPTURE value BALANCE after settlement		---
		---------------------------VVVV------------------------------
		INSERT INTO @BalanceWalletAfter (matchID, custID, balanceType, WalletType, BonusID, balance)
		EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
					@MatchID		  	= 0
					,@sportType			= 0
					,@Action 			= @Action
					,@Mode 			  	= 2 --Used for Manual settle process
					,@TransIDs			= @TransIDs
	
					
		-- Compare and update pending balance with error case
		EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
					@BalanceWalletBefore	= @BalanceWalletBefore
					,@BalanceWalletAfter	= @BalanceWalletAfter
					,@ActionID				= @ActionID
		
		
					
		SELECT @balanceCountChanged = COUNT(DISTINCT a.custID)
		FROM @BalanceWalletAfter a
			INNER JOIN @BalanceWalletBefore b 
			ON	 a.matchID				= b.matchID
					AND a.custID		= b.custID
					AND a.balanceType	= b.balanceType
					AND a.walletType	= b.walletType
					AND a.bonusID		= b.bonusID
		WHERE a.balance <> b.balance
		
		
	END TRY
	BEGIN CATCH
		  -------------------------------------------------------------
		  ---		 CAPTURE value BALANCE after settlement		---
		  ---------------------------VVVV------------------------------
		  
		  INSERT INTO @BalanceWalletAfter (matchID, custID, balanceType, WalletType, BonusID, balance)
		  EXEC [dbo].[NAP_Admin_CaptureBalanceByWallet]
				  @MatchID 				= 0
				  , @sportType			= 0
				  , @Action 			= @Action 
				  , @Mode 				= 2 --Used for Manual settle process
				  , @TransIDs			= @TransIDs
	
		  -- Compare and update pending balance with error case
		  EXEC [dbo].[NAP_Admin_BalancePending_WalletUpd]
				  @BalanceWalletBefore	= @BalanceWalletBefore
				  , @BalanceWalletAfter	= @BalanceWalletAfter
				  , @ActionID			= @ActionID
		  
		  SELECT @balanceCountChanged = COUNT(DISTINCT a.custID)
			FROM @BalanceWalletAfter a
				INNER JOIN @BalanceWalletBefore b 
				ON	 a.matchID				= b.matchID
						AND a.custID		= b.custID
						AND a.balanceType	= b.balanceType
						AND a.walletType	= b.walletType
						AND a.bonusID		= b.bonusID
			WHERE a.balance <> b.balance
			
		  SELECT	@ErrCode = 1001017
					,@ErrMsg = ERROR_MESSAGE() + ERROR_PROCEDURE()
	
		  
	END CATCH
END

GO