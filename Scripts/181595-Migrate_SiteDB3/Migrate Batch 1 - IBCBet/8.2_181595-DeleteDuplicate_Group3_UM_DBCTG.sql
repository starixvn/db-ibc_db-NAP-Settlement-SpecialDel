/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Delete duplicate data - table group 3 [Redmineid:#181595] 
		
*/

USE SiteDBtmp
GO

	-- Remove duplicate data if page split

	--bettransm
	;WITH cteDuplicate
	AS(
		SELECT	transid	,ROW_NUMBER() OVER(PARTITION BY transid ORDER BY transid) as rn 
		FROM	bettransm_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--zzzbettrans
	;WITH cteDuplicate
	AS(
		SELECT	keyid ,ROW_NUMBER() OVER(PARTITION BY keyid ORDER BY keyid) as rn 
		FROM	zzzbettrans_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--zzzbettransm
	;WITH cteDuplicate
	AS(
		SELECT	keyid ,ROW_NUMBER() OVER(PARTITION BY keyid ORDER BY keyid) as rn 
		FROM	zzzbettransm_UM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1