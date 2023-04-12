/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Admin_Settlement_BalanceUpd
(	 @BalanceChanged		TVP_BalanceWalletChange READONLY 
	,@ActionID              INT  
	,@ErrMessage			VARCHAR(300) = '' OUTPUT
	,@ErrCode				INT			 = 0  OUTPUT
)
AS
/*	
	Created: 20230207@Aries
	Task: Apply Settlement by Profile for Remaining Sports 
	DB: DBTXN-bodb02

	Revisions: 
        - 20230214@Aries: Created [Redmine: #182677]
		
	Param's Explanation:

*/	
BEGIN
	SET NOCOUNT ON

	DECLARE	 @StepNumber			INT = 0
            ,@CheckNegativeBalance  INT = 0 

	BEGIN TRY
		SET @StepNumber = 1

		INSERT INTO dbo.BalCreditSportsPending (custid, balance)
		SELECT	custid, SUM(Balance) Balance
		FROM	@BalanceChanged t
		GROUP BY custid
		HAVING SUM(Balance) > 0
	
		SET @StepNumber = 2

		INSERT INTO dbo.BalDebitSportsPending(custid, balance)
		SELECT	custid, ABS(SUM(Balance)) Balance
		FROM	@BalanceChanged t
		GROUP BY custid
		HAVING SUM(Balance) < 0
		SET @CheckNegativeBalance = @@ROWCOUNT
	
		SET @StepNumber = 3

		IF @CheckNegativeBalance <> 0
		BEGIN
			INSERT INTO [dbo].[BalanceNegative] (
				[ExecDate]
				,[MatchID]
				,[ActionID]
				,[GroupID]
				,[CustID]
				,[Balance]
				,[StatusID]
				,[Remark]
			)
			SELECT	GETDATE()
					,MatchID
					,@ActionId
					,1 AS GroupID 
					,CustID
					,SUM(Balance)
					,0
					,NULL
			FROM	@BalanceChanged bal
			GROUP BY bal.CustId, bal.MatchID
			HAVING SUM(Balance) < 0
		END

		SET @StepNumber = 4

	END TRY
	BEGIN CATCH
			SET @ErrCode = @StepNumber
			SET @ErrMessage = ERROR_MESSAGE()

			INSERT INTO dbo.BalanceErr (Custid, BalanceGroup, BalanceAmt, ExecutedSP, ErrMsg)
			SELECT	bn.Custid
					, 1 AS BalanceGroup
					, SUM(bn.balance) AS BalanceAmt
					, 'NAP_Admin_Settlement_BalanceUpd' AS ExecutedSP
					, LEFT(ERROR_MESSAGE(),500) AS ErrMsg
			FROM	@BalanceChanged bn
			GROUP BY bn.CustId
			HAVING SUM(bn.balance) <> 0	
	END CATCH

END
GO