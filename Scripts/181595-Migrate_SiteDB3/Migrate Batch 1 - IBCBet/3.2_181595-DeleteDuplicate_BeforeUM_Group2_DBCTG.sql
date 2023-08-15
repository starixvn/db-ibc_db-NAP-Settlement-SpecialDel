/*<info serverAlias="DBCTG-SiteDBtmp" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBCTG-SiteDBtmp

	Revisions:
		- 20230727@Louisa: Delete duplicate data - before UM - Group 2 [Redmineid:#181595] 
		
*/

USE SiteDBtmp
GO

	-- Remove duplicate data if page split

	--zzzbettrans
	;WITH cteDuplicate
	AS(
		SELECT	keyid ,ROW_NUMBER() OVER(PARTITION BY keyid ORDER BY keyid) as rn 
		FROM	zzzbettrans_BeforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1

	--zzzbettransm
	;WITH cteDuplicate
	AS(
		SELECT	keyid ,ROW_NUMBER() OVER(PARTITION BY keyid ORDER BY keyid) as rn 
		FROM	zzzbettransm_BeforeUM WITH(NOLOCK)
	)
	DELETE FROM	cteDuplicate
	WHERE	rn > 1