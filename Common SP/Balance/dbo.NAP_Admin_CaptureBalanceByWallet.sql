/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
CREATE PROCEDURE [dbo].[NAP_Admin_CaptureBalanceByWallet]
	@MatchId 			INT
	, @Action 			VARCHAR(10)
	, @Mode 			TINYINT = 1
	, @SelectedQuarter 	VARCHAR(50)		= NULL
	, @SelectedSet    	VARCHAR(50)		= NULL 
AS
/* 
	Created: 20170419@Bobby.nguyen  
	Task:  75500 - Implement bonus system into NAP Settlement
	DB: DBTXN/bodb02  
	Original:   

	Revisions:  

	Param's Explanation:   
		@Mode: 1: Used for Auto payout process
			   2: Used for Manual settle process
			   3: Used for Manual refund process
			   4: Used for CAL FGLG
			   5: Used for Conner
			   6: Used for Auto Settlement
			   7: Used for Fast Market
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @sportType			INT
		, @isTrading			BIT
		, @balanceType			TINYINT
	
	DECLARE @capturedBalance	TVP_BalanceWalletChange
	
	--CHECK sportType & trading bet
	SELECT TOP(1) @SportType 	= sportType
		, @isTrading 			= ISNULL(trade.IsTrading, 0)
	FROM dbo.match m WITH(NOLOCK)
		OUTER APPLY (
			SELECT TOP(1) CAST(1 AS BIT) AS IsTrading
			FROM dbo.bettrans b WITH(NOLOCK)
			WHERE matchid 	= @matchid
				AND EXISTS ( 
					SELECT TOP 1 1
					FROM dbo.f_Settle_GetTradingBettype() 
					WHERE bettype = b.bettype
				)
		) AS trade
	WHERE matchid = @matchid
	
	IF(@SportType > 0)
	BEGIN		
		SELECT @balanceType = CASE 
								WHEN (@sportType BETWEEN 1 AND 99 OR @sportType = 154) THEN 1 -- Sports
								WHEN (@sportType = 162) THEN 3 -- Casino
								ELSE 4  -- Others
							END
	
		IF (@sportType NOT IN (2, 5)) --excluding tennis and baseketball
		BEGIN
			INSERT INTO @capturedBalance(
				matchid
				,custid
				,balanceType
				,walletType
				,bonusId
				,balance
			)
			SELECT matchid
				, custid
				, @balanceType
				, WalletType
				, BonusID
				, balance 
			FROM dbo.f_Settle_GetBalanceByBettype (
				@MatchId
				, @Action
				, @Mode
				, @isTrading
			)
		END
		ELSE
		BEGIN
			INSERT INTO @capturedBalance(
				matchid
				,custid
				,balanceType
				,walletType
				,bonusId
				,balance
			)
			SELECT matchid
				, custid
				, @balanceType AS balanceType
				, WalletType
				, BonusID
				, balance 
			FROM dbo.f_Settle_GetBalanceByBettypeTicket (
				@MatchId
				, @Action
				, @Mode
				, @SportType
				, @SelectedQuarter
				, @SelectedSet
			)
		END
	END
	
	--OUTPUT captured balance
	SELECT matchid
		,custid
		,balanceType
		,walletType
		,bonusId
		,balance
	FROM @capturedBalance
	
END
GO
