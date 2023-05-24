/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_BalancePending_WalletUpd]
	@BalanceWalletBefore	TVP_BalanceWalletChange	READONLY
	, @BalanceWalletAfter	TVP_BalanceWalletChange	READONLY
	, @ActionId				INT = 0
AS
/* 
	Created: 20170419@Bobby.nguyen  
	Task:  75500 - Implement bonus system into NAP Settlement
	DB: DBTXN/bodb02  
	Original:   

	Revisions:  
		- 20170419@Bobby.nguyen: Initial
		- 20171009@Kathy: Change column name of BonusAdjustmentTransfer [Redmine:#72789]
		- 20220511@Kathy: Force hash join when check balance [Redmine:#172624]
		- 20230523@Kathy: scaleout - credit [Redmine:#188452]

	Param's Explanation:   
		- @ActionId		  : INT 
			+ Keep tracing the action log which is the root cause of negative balance
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MatchId INT
	
	--FOR genneral wallet
	DECLARE @GeneralBeforeUpd 	TVP_BalanceChange
	DECLARE @GeneralAfterUpd 	TVP_BalanceChange
	DECLARE @tmpBalanceNegative TABLE (CustId INT, Balance MONEY)

	BEGIN --GATHER genneral balance
		INSERT INTO @GeneralBeforeUpd (custid, balanceType, balance)
		SELECT	bal.custid
				, bal.balanceType
				, SUM(balance) AS balance
		FROM	@BalanceWalletBefore bal
		WHERE	bal.walletType = 2
		GROUP BY bal.custid, bal.balanceType
			
		--GATHER balance after
		INSERT INTO @GeneralAfterUpd (custid, balanceType, balance)
		SELECT	bal.custid
				, bal.balanceType
				, SUM(balance) AS balance
		FROM	@BalanceWalletAfter bal
		WHERE bal.walletType = 2
		GROUP BY bal.custid, bal.balanceType
	
		--UPDATE genneral wallet
		IF(@@ROWCOUNT > 0)
		BEGIN
			EXEC [dbo].[NAP_Admin_BalancePendingIns]
			@BeforeUpd	= @GeneralBeforeUpd
			,@AfterUpd  = @GeneralAfterUpd
		END
		
	END
	
	/*
	CHECKING negative balance
	@ActionID: INT
		- 182: Inst.CAL - UNDO
		- 103: Munual.CAL - UNDO
		- 157-158: Auto Payout (HT-FT)
		- 148-149-150: Auto BetRadar (CAL-UNDO-REFUND)
		- 109-110-111: Manual Refund(ALL-HT-FT)
	*/
	IF (@ActionID > 0) AND OBJECT_ID('BalanceNegative','U') IS NOT NULL
	BEGIN 
		SELECT TOP 1 @MatchId = matchid
		FROM @BalanceWalletBefore

		INSERT INTO @tmpBalanceNegative(CustId, Balance)
		SELECT
			b.custid
			,SUM(a.balance - b.balance) AS balance
		FROM @GeneralBeforeUpd b
			INNER HASH JOIN @GeneralAfterUpd a 
				ON b.custid 		= a.custid
				AND b.balanceType	= a.balanceType 
		GROUP BY b.custid				
		HAVING SUM(a.balance) < SUM(b.balance)
		
		----
		-- Add Negative Balance into BalanceNegative table 
		----
		INSERT INTO [bodb02].[dbo].[BalanceNegative] (
				[ExecDate]
				,[MatchID]
				,[ActionID]
				,[GroupID]
				,[CustID]
				,[Balance]
				,[StatusID]
				,[Remark]
		)
		SELECT GETDATE()
				,@MatchID
				,@ActionId
				,ISNULL(bg.GroupID,1) AS GroupID -- Negative balance defined group Id
				,CustID
				,Balance
				,0
				,NULL
		FROM @tmpBalanceNegative bal
			LEFT JOIN dbo.f_Set_NegativeBalance_ActionGroup() AS bg
			ON bg.ActionId = @ActionId
	END
END
GO
