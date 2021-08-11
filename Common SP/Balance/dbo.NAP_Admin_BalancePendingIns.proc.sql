/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_BalancePendingIns]
	@BeforeUpd	TVP_BalanceChange	READONLY
	,@AfterUpd	TVP_BalanceChange	READONLY
AS
/* 
	Created by: Bobby  
	Task:  VOID BY BET ID (Running & Settled tickets)  
	DB: DBTXN/bodb02  
	Original:   
	   
	Revisions:  
		- 20170420@Bobby: 72789 - Implement bonus system into NAP Settlement
		- 20210811@Kathy: Force hash join for balancetype 1 [Redmine:#160017]
		
	Param's Explanation:   	 
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tblDebitPending TVP_BalanceList
	DECLARE @tblCreditPending TVP_BalanceList
		
	DECLARE @tblDebitOthersPending TVP_BalanceList
	DECLARE @tblCreditOthersPending TVP_BalanceList
	 
	DECLARE @tblDebitCasinoPending TVP_BalanceList
	DECLARE @tblCreditCasinoPending TVP_BalanceList
	
	--select * from @BeforeUpd
	--select * from @AfterUpd
	
	--BALANCE Credit
	INSERT INTO @tblCreditPending (custid,Balance)  
	SELECT	a.custid, (a.balance - b.balance) as Balance  
	FROM	@BeforeUpd b  
	INNER HASH JOIN @AfterUpd a    
		ON	a.custid = b.custid  
	WHERE  (a.balance - b.balance) > 0
		AND a.balanceType = 1
		AND b.balanceType = 1  
		
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditPending
			,@Type			= 1 -- Sports
	
	
	INSERT INTO @tblCreditCasinoPending (custid,Balance)  
	SELECT  a.custid, (a.balance - b.balance) as Balance  
	FROM  @BeforeUpd b  
		INNER JOIN @AfterUpd a    
			ON	a.custid = b.custid  
	WHERE  (a.balance - b.balance) > 0
			AND a.balanceType = 3
			AND b.balanceType = 3

	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditCasinoPending
			,@Type			= 3 -- Casino
		
	INSERT INTO @tblCreditOthersPending (custid,Balance)  
	SELECT  a.custid, (a.balance - b.balance) as Balance  
	FROM	@BeforeUpd b  
		INNER JOIN @AfterUpd a    
			ON	a.custid = b.custid  
	WHERE  (a.balance - b.balance) > 0
			AND a.balanceType = 4
			AND b.balanceType = 4
		
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingCreditIns 
			@BalancePending = @tblCreditOthersPending
			,@Type			= 4 -- Others
	
	
	
	
	--BALANCE Debit
	INSERT INTO @tblDebitPending (custid,Balance)  
	SELECT  a.custid, ABS(a.balance - b.balance) as Balance  
	FROM  @BeforeUpd b  
		INNER HASH JOIN @AfterUpd a    
			ON	a.custid = b.custid  
	WHERE  (a.balance - b.balance) < 0  
			AND a.balanceType = 1
			AND b.balanceType = 1
		
	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitPending
			,@Type			= 1 -- Sports
	 
	INSERT INTO @tblDebitCasinoPending (custid,Balance)  
	SELECT  a.custid, ABS(a.balance - b.balance) as Balance  
	FROM  @BeforeUpd b  
		INNER JOIN @AfterUpd a    
			ON	a.custid = b.custid  
	WHERE	(a.balance - b.balance) < 0 
			AND a.balanceType = 3
			AND b.balanceType = 3 

	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitCasinoPending
			,@Type			= 3 -- Casino
	 
	INSERT INTO @tblDebitOthersPending (custid,Balance)  
	SELECT  a.custid, ABS(a.balance - b.balance) as Balance  
	FROM  @BeforeUpd b  
		INNER JOIN @AfterUpd a    
			ON a.custid = b.custid  
	WHERE   (a.balance - b.balance) < 0  
			AND a.balanceType = 4
			AND b.balanceType = 4

	IF @@rowcount <> 0
		EXEC dbo.Dot_BalancePendingDebitIns 
			@BalancePending = @tblDebitOthersPending
			,@Type			= 4 -- Others
			
	RETURN
END
GO
