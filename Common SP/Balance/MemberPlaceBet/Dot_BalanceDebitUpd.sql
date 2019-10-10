/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Dot_BalanceDebitUpd]
(
	@custID			INT,
	@balance		MONEY,
	@type			TINYINT,
	@isForced		BIT = 0, 
	@total			MONEY = 0 OUTPUT,
	@errCode		INT = 0 OUTPUT,
	-------- bonus wallet --------
	@walletType 	TINYINT = 2,
	@bonusId		INT = 0,
	@bonusbalance	MONEY = 0,
	------- givenCredit ---------
	@givenCredit MONEY = NULL,
	@Amount			MONEY = 0 OUTPUT
)
AS
/*
	Created: 20150731@Lukas
	Task: Update credit balance by single member
	DB: DBTXN/bodb02
		
	Revisions:
		- 20160204@Sylvia(DBTrans): add NetPosition balance
		- 20160217@Sylvia(DBTrans): fix NP balance bug, use sub query to sum NP first.
		- 20170505@Bobby: 
			+ Implement bonus wallet by adding params (@walletType,@bonusId,@Bonus)
			+ Move original SP's content to SP Dot_BalanceDebit_GeneralWalletlUpd
		- 20171009@Kathy: Change parameter name of SP Dot_BalanceDebit_BonusWalletlUpd [Redmine:#72789]
		- 20191010@Helen: add new input parameter @givenCredit [Redmine:121761]
		
	Params explanation
		@type:
			1 - Sports
			2 - Transfer
			3 - Casino
			4 - Others
		@errCode:
			100: invalid @type
			101: no update due to insufficient balance
			102: general wallet updated with error
			103: bonus wallet updated with error
			104: bonus wallet updated without member
			
		@total: total cash balance after update
		@isForced: this param indicate that balance still deducted, no matter what balance is (rollback, recover,... even those actions cause negative balance)
		@bonusId: the active bonus program Id
		@walletType: [1,2]. SET defaut(2) as cash wallet and 3:both
		@Amount : available bonus amount after update
	
	
	
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @bonusFlag		TINYINT
		,@cashBalance		MONEY
		,@bonusBalanceUpd	MONEY
	
	SELECT @errCode 		= 0
		,@total 			= 0
		,@Amount			= 0
		,@bonusFlag			= 0 --CASH as defaut
	
	--CHECK bonus program status
	IF(@walletType IN (1, 3) AND @bonusId > 0)
	BEGIN
		SELECT @bonusFlag = st.BonusFlag
		FROM dbo.BonusWalletCredit bc WITH(NOLOCK) 
			INNER JOIN dbo.f_Set_BonusWallet_StatusSel () AS st
			ON bc.StatusId = st.StatusId
		WHERE bc.custID = @custID
			AND bc.bonusId = @bonusId
	END
	
	--step1 -> CHECK updating for general wallet first
	SELECT @cashBalance = CASE 
								WHEN @bonusFlag IN (0, 1) AND @walletType = 3 THEN (@bonusbalance+@balance)
								WHEN @bonusFlag IN (0, 1) THEN @balance 
							ELSE 0 END
	--UPDATE general wallet
	IF @givenCredit IS NULL
	BEGIN
		EXEC [dbo].[Dot_BalanceDebit_GeneralWalletUpd]
			@custID			= @custID
			, @balance		= @cashBalance
			, @type			= @type
			, @isForced		= @isForced
			, @total		= @total OUTPUT --alway get total balance for output
			, @errCode		= @errCode OUTPUT
	END
	ELSE 
	BEGIN
		EXEC [dbo].[Dot_BalanceDebit_GeneralWalletUpd_new]
			@custID			= @custID
			, @balance		= @cashBalance
			, @type			= @type
			, @isForced		= @isForced
			, @givenCredit	= @givenCredit
			, @total		= @total OUTPUT --alway get total balance for output
			, @errCode		= @errCode OUTPUT
	END
	--step2 -> CHECK for updating bonus wallet second
	IF(@errCode 		= 0 
		AND @walletType IN (1,3) 
		AND @bonusId 	> 0
	)
	BEGIN
	
		SELECT @bonusBalanceUpd = CASE WHEN @walletType = 3 THEN @bonusBalance ELSE @balance END
	
		--UPDATE bonus wallet
				EXEC dbo.Dot_BalanceDebit_BonusWalletUpd
			@custID				= @custID
			, @BonusId			= @bonusId
			, @balance			= @bonusBalanceUpd
			, @Amount			= @Amount OUTPUT
			, @errCode			= @errCode OUTPUT
		
		-- FAILED bonus wallet -> DO ROLLBACK for general wallet at step1
		IF(@errCode > 0)
		BEGIN
				EXEC [dbo].[Dot_BalanceCredit_GeneralWalletUpd]
				@custID			= @custID
				, @balance		= @cashBalance
				, @type			= @type
			
			--ROLLBACK to original total
			SELECT @total		+= @cashBalance
		END
	END
	
END
GO


