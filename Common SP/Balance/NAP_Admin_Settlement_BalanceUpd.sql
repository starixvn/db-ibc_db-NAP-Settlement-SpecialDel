/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
CREATE PROCEDURE dbo.NAP_Admin_Settlement_BalanceUpd
(	 @BalanceChanged		TVP_BalanceWalletChange READONLY 
	,@ActionID              INT  
	,@BalanceType			TINYINT	 = 1 --sport
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
		- 20230523@Kathy: remove un-used table [Redmine:#188452]
		- 20230704@Louisa:  Virtual Leap Gaming - VS3 [Redmine:#189854]

	Param's Explanation:

*/	
BEGIN
	SET NOCOUNT ON

	DECLARE	 @StepNumber			INT = 0
            ,@CheckNegativeBalance  INT = 0 

	BEGIN TRY

		SET @StepNumber = 1
		IF @BalanceType = 1
		BEGIN
			INSERT INTO dbo.BalCreditSportsPending (custid, balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@BalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) > 0
		END
		ELSE IF @BalanceType = 4
		BEGIN
			INSERT INTO dbo.BalCreditOthersPending(custid, Balance)
			SELECT	custid, SUM(Balance) Balance
			FROM	@BalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) > 0
		END
		
		SET @StepNumber = 2
		IF @BalanceType = 1
		BEGIN
			INSERT INTO dbo.BalDebitSportsPending(custid, balance)
			SELECT	custid, ABS(SUM(Balance)) Balance
			FROM	@BalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) < 0
			
			SET @CheckNegativeBalance = @@ROWCOUNT
		END
		ELSE IF @BalanceType = 4
		BEGIN
			INSERT INTO dbo.BalDebitOthersPending(custid, Balance)
			SELECT	custid, ABS(SUM(Balance)) Balance
			FROM	@BalanceChanged t
			GROUP BY custid
			HAVING SUM(Balance) < 0

			SET @CheckNegativeBalance = @@ROWCOUNT
		END

		SET @StepNumber = 3		
		IF @CheckNegativeBalance <> 0 AND OBJECT_ID('BalanceNegative','U') IS NOT NULL
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
					,CASE WHEN @BalanceType = 4 THEN 7 ELSE 1 END AS GroupID 
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