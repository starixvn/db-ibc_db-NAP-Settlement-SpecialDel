/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Delete duplicate data - before UM - group 3 [Redmineid:#181595] 
		
*/

USE SiteDBtmp
GO

	-- Remove duplicate data if page split

	--Bettrans14
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Bettrans14_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransInfo14
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransInfo14_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--bettransm14
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	bettransm14_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransLC14
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransLC14_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransRnG14
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransRnG14_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--bettransG14
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	bettransG14_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Translog14
	;WITH cteDuplicate
	AS(
		SELECT	translogid	,ROW_NUMBER() OVER(PARTITION BY translogid ORDER BY translogid) as rn 
		FROM	Translog14_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Task_bettrans14_IP2Country
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Task_bettrans14_IP2Country_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Task_bettransRNG14_IP2Country
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Task_bettransRNG14_IP2Country_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Task_bettransLC14_IP2Country
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Task_bettransLC14_IP2Country_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--balanceTable_tmp
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	balanceTable_tmp_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Task_Cust_CheckBalance_Exception
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	Task_Cust_CheckBalance_Exception_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Task_Cust_BalanceProblem1
	;WITH cteDuplicate
	AS(
		SELECT	keyID	,ROW_NUMBER() OVER(PARTITION BY keyID ORDER BY keyID) as rn 
		FROM	Task_Cust_BalanceProblem1_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--ProcessingCustList
	;WITH cteDuplicate
	AS(
		SELECT	CustId	,ROW_NUMBER() OVER(PARTITION BY CustId ORDER BY CustId) as rn 
		FROM	ProcessingCustList_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Task_Cust_BalanceProblem1_Manually
	;WITH cteDuplicate
	AS(
		SELECT	keyID	,ROW_NUMBER() OVER(PARTITION BY keyID ORDER BY keyID) as rn 
		FROM	Task_Cust_BalanceProblem1_Manually_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--sum_winloss
	;WITH cteDuplicate
	AS(
		SELECT	keyid	,ROW_NUMBER() OVER(PARTITION BY keyid ORDER BY keyid) as rn 
		FROM	sum_winloss_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

