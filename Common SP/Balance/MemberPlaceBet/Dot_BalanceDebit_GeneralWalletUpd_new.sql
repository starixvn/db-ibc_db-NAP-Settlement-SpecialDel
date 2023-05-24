/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
CREATE PROCEDURE [dbo].[Dot_BalanceDebit_GeneralWalletUpd_new]
(
	@custID		INT,
	@balance	MONEY,
	@type		TINYINT,
	@isForced	BIT = 0, 
	@givenCredit MONEY,
	@total		MONEY = 0 OUTPUT,
	@errCode	INT = 0 OUTPUT
)
AS
/*
	Created: 20150731@Lukas
	Task: Update credit balance by single member
	DB: DBTXN/bodb02
	Original: Dot_BalanceDebitUpd
	
	Revisions:	
		- 20160204@Sylvia(DBTrans): add NetPosition balance
		- 20160217@Sylvia(DBTrans): fix NP balance bug, use sub query to sum NP first.
		- 20170505@Bobby: 72789 - Implement bonus wallet into balance
		- 20191010@Helen: add new input parameter @givenCredit [Redmine:121761]
		- 20230523@Kathy: remove un-used table [Redmine:#188452]

	Params explanation
		@type:
			1 - Sports
			2 - Transfer
			3 - Casino
			4 - Others
		@errCode:
			100: invalid @type
			101: no update due to insufficient balance
			102: prcess error
			
		@total: total cash balance after update
		@isForced: this param indicate that balance still deducted, no matter what balance is (rollback, recover,... even those actions cause negative balance)
*/
BEGIN
	SET NOCOUNT ON 
	
	SET @errCode = 0
	DECLARE @BalanceMode TINYINT --0: Old, 1: New, 2: Both	
	SELECT @BalanceMode = dbo.f_GetBalanceMode()
	
	IF @BalanceMode IN (1, 2)
	BEGIN
		IF @type NOT IN (1,2,3,4)
		BEGIN
			SET @errCode = 100 --invalid type
			RETURN
		END 
		
		--for both mode test only
		--IF @type IN (1,3,4) SET @isForced = 1 

		DECLARE @Retry INT = 0 
		DECLARE @Success BIT = 0
		DECLARE @rowcount INT = 0
		DECLARE @cashBalance MONEY = 0
	
		WHILE (@Success = 0 AND @Retry < 3)
		BEGIN
			BEGIN TRY
				SET @Retry = @Retry + 1
				SET @Success = 1

				IF @Type = 1 -- Sports
				BEGIN				
					UPDATE ds WITH(ROWLOCK,UPDLOCK)
					SET @cashBalance = (cs.Balance + cc.Balance + co.Balance + ct.Balance + isnull(np.NPbal,0)) - (ds.Balance + dc.Balance + do.Balance + dt.Balance)
						,@errCode = CASE WHEN @isForced = 1 OR @givenCredit + @cashBalance >= @balance THEN 0 ELSE 101 END 
						,@total = @givenCredit + @cashBalance - CASE WHEN @errCode = 101 THEN 0 ELSE @balance END
						,ds.balance += CASE WHEN @errCode = 101 THEN 0 ELSE @balance END							
					FROM dbo.BalDebitSports					ds
						INNER JOIN dbo.BalDebitCasino		dc ON ds.custid = dc.custid -- need to lock on debit tables
						INNER JOIN dbo.BalDebitTransfer		dt ON ds.custid = dt.custid 
						INNER JOIN dbo.BalDebitOthers		do ON ds.custid = do.custid 
						INNER JOIN dbo.BalCreditSports		cs WITH(NOLOCK) ON ds.custid = cs.custid 
						INNER JOIN dbo.BalCreditCasino		cc WITH(NOLOCK) ON ds.custid = cc.custid 
						INNER JOIN dbo.BalCreditTransfer	ct WITH(NOLOCK) ON ds.custid = ct.custid 
						INNER JOIN dbo.BalCreditOthers		co WITH(NOLOCK) ON ds.custid = co.custid
						LEFT JOIN (select custid,sum(Credit-Debit) as NPbal from dbo.BalNetPosition WITH(NOLOCK) where CustID=@custid group by custid) np ON ds.custid = np.custid
					WHERE ds.custid = @custid					
			
					SET @rowcount = @@ROWCOUNT
			
				END
				ELSE IF @Type = 2 -- Transfer    /*** cash balance only, no  givencredit involved****/
				BEGIN
					UPDATE dt WITH(ROWLOCK,UPDLOCK)
					SET @cashBalance = (cs.Balance + cc.Balance + co.Balance + ct.Balance) - (ds.Balance + dc.Balance + do.Balance + dt.Balance)
						,@errCode = CASE WHEN @isForced = 1 OR @cashBalance >= @balance THEN 0 ELSE 101 END
						,@total = @cashBalance - CASE WHEN @errCode = 101 THEN 0 ELSE @balance END
						,dt.balance += CASE WHEN @errCode = 101 THEN 0 ELSE @balance END														
					FROM dbo.BalDebitTransfer				dt		
						INNER JOIN dbo.BalDebitSports		ds ON dt.custid = ds.custid -- need to lock on debit tables
						INNER JOIN dbo.BalDebitCasino		dc ON dt.custid = dc.custid 
						INNER JOIN dbo.BalDebitOthers		do ON dt.custid = do.custid 					
						INNER JOIN dbo.BalCreditTransfer	ct WITH(NOLOCK) ON dt.custid = ct.custid
						INNER JOIN dbo.BalCreditSports		cs WITH(NOLOCK) ON dt.custid = cs.custid 
						INNER JOIN dbo.BalCreditCasino		cc WITH(NOLOCK) ON dt.custid = cc.custid						 
						INNER JOIN dbo.BalCreditOthers		co WITH(NOLOCK) ON dt.custid = co.custid 
					WHERE dt.custid = @custid					

					SET @rowcount = @@ROWCOUNT
				END
				ELSE IF @Type = 3 -- Casino
				BEGIN
					UPDATE dc WITH(ROWLOCK,UPDLOCK)
					SET @cashBalance = (cs.Balance + cc.Balance + co.Balance + ct.Balance + isnull(np.NPbal,0)) - (ds.Balance + dc.Balance + do.Balance + dt.Balance)
						,@errCode = CASE WHEN @isForced = 1 OR @givenCredit + @cashBalance >= @balance THEN 0 ELSE 101 END
						,@total = @givenCredit + @cashBalance - CASE WHEN @errCode = 101 THEN 0 ELSE @balance END
						,dc.balance	+= CASE WHEN @errCode = 101 THEN 0 ELSE @balance END
					FROM dbo.BalDebitCasino					dc			 
						INNER JOIN dbo.BalDebitSports		ds ON dc.custid = ds.custid -- need to lock on debit tables 			 
						INNER JOIN dbo.BalDebitTransfer		dt ON dc.custid = dt.custid 
						INNER JOIN dbo.BalDebitOthers		do ON dc.custid = do.custid 
						INNER JOIN dbo.BalCreditCasino		cc WITH(NOLOCK) ON dc.custid = cc.custid
						INNER JOIN dbo.BalCreditSports		cs WITH(NOLOCK) ON dc.custid = cs.custid
						INNER JOIN dbo.BalCreditTransfer	ct WITH(NOLOCK) ON dc.custid = ct.custid 
						INNER JOIN dbo.BalCreditOthers		co WITH(NOLOCK) ON dc.custid = co.custid 
						LEFT JOIN (select custid,sum(Credit-Debit) as NPbal from dbo.BalNetPosition WITH(NOLOCK) where CustID=@custid group by custid) np ON ds.custid = np.custid
					WHERE dc.custid = @custid					

					SET @rowcount = @@ROWCOUNT
				END 
				ELSE IF @Type = 4 -- Others
				BEGIN
					UPDATE do WITH(ROWLOCK,UPDLOCK)
					SET @cashBalance = (cs.Balance + cc.Balance + co.Balance + ct.Balance + isnull(np.NPbal,0)) - (ds.Balance + dc.Balance + do.Balance + dt.Balance)
						,@errCode = CASE WHEN @isForced = 1 OR @givenCredit + @cashBalance >= @balance THEN 0 ELSE 101 END
						,@total = @givenCredit + @cashBalance - CASE WHEN @errCode = 101 THEN 0 ELSE @balance END
						,do.balance	+= CASE WHEN @errCode = 101 THEN 0 ELSE @balance END
					FROM dbo.BalDebitOthers					do		
						INNER JOIN dbo.BalDebitSports		ds ON do.custid = ds.custid -- need to lock on debit tables 			 
						INNER JOIN dbo.BalDebitCasino		dc ON do.custid = dc.custid 
						INNER JOIN dbo.BalDebitTransfer		dt ON do.custid = dt.custid 
						INNER JOIN dbo.BalCreditOthers		co WITH(NOLOCK) ON do.custid = co.custid
						INNER JOIN dbo.BalCreditSports		cs WITH(NOLOCK) ON do.custid = cs.custid
						INNER JOIN dbo.BalCreditCasino		cc WITH(NOLOCK) ON do.custid = cc.custid 
						INNER JOIN dbo.BalCreditTransfer	ct WITH(NOLOCK) ON do.custid = ct.custid 	
						LEFT JOIN (select custid,sum(Credit-Debit) as NPbal from dbo.BalNetPosition WITH(NOLOCK) where CustID=@custid group by custid) np ON ds.custid = np.custid
					WHERE do.custid = @custid					

					SET @rowcount = @@ROWCOUNT
				END  
			
			END TRY
			BEGIN CATCH
				SET @errCode = 102
				SET @Success = 0
			
				INSERT INTO BalanceErr ( Custid, BalanceGroup, BalanceAmt, ExecutedSP, ErrMsg )
				VALUES ( @custid, @Type, @balance,'Dot_BalanceDebit_GeneralWalletUpd',LEFT(ERROR_MESSAGE(),500))
				
			END CATCH 
		END -- end while

		IF @rowcount = 0 --missing customer in balance tables? insert it and try again
		BEGIN		
			EXEC [dbo].[Dot_BalanceReinitData] @custid = @custid, @errCode = @errCode OUTPUT
			IF @errCode = 0 OR @errCode IS NULL
			BEGIN
								EXEC [dbo].[Dot_BalanceDebit_GeneralWalletUpd] @custid = @custid, @balance = @balance, @type = @type, @isForced = @isForced, @total = @total OUTPUT, @errCode = @errCode OUTPUT
				RETURN
			END
		END
	END
END
GO


