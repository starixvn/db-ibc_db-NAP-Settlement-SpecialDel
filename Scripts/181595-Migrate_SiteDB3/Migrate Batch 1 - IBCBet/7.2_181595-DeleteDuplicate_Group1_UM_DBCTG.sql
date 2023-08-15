/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Delete duplicate data - table group 1 [Redmineid:#181595] 
		
*/

USE SiteDBtmp
GO

	-- Remove duplicate data if page split

	--BalDebitCasino
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalDebitCasino_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalDebitOthers
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalDebitOthers_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalDebitSports
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalDebitSports_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalDebitTransfer
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalDebitTransfer_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalCreditCasino
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalCreditCasino_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalCreditOthers
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalCreditOthers_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalCreditSports
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalCreditSports_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BalCreditTransfer
	;WITH cteDuplicate
	AS(
		SELECT	custid	,ROW_NUMBER() OVER(PARTITION BY custid ORDER BY custid) as rn 
		FROM	BalCreditTransfer_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1
