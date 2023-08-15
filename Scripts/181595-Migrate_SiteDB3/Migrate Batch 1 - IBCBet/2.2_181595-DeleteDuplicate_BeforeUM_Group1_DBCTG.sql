/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Delete duplicate data - before UM - Group 1 [Redmineid:#181595] 
		
*/

USE SiteDBtmp
GO

	-- Remove duplicate data if page split

	--Bettrans 
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Bettrans_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransInfo 
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransInfo_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransLC
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransLC_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--BettransRnG
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	BettransRnG_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--bettransG
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	bettransG_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Translog
	;WITH cteDuplicate
	AS(
		SELECT	translogid	,ROW_NUMBER() OVER(PARTITION BY translogid ORDER BY translogid) as rn 
		FROM	Translog_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Transfer
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Transfer_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--Transfer_Coll
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	Transfer_Coll_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--TransferInfo
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	TransferInfo_beforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1
