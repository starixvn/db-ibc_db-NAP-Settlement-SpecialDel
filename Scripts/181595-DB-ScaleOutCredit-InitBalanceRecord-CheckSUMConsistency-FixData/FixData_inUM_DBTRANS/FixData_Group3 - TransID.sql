--Group 2 - In UM - fix data
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: fix data on sitedb03 [Redmineid:#181595] 

		1) Bettransm    
		2) zzzbettrans  
		3) zzzbettransm 

*/
----------correct tickets---------------------------------
/* find text and replace by list of wrong recommends for table need to fix data
1) Bettransm    -> bettransm_TransidList
2) zzzbettrans  -> zzzbettrans_KeyIDList
3) zzzbettransm -> zzzbettransm_KeyIDList

*/
BEGIN--------1) Bettransm  --------------------------------------

	UPDATE b 
		SET
			RepUpdateTime = SYSDATETIME()
	FROM Bettransm b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (bettransm_TransidList)

END
BEGIN--------2) zzzbettrans  --------------------------------------
	
	UPDATE b	
		SET 
			RepUpdateTime = SYSDATETIME()
	FROM zzzbettrans b WITH (ROWLOCK, UPDLOCK)
	WHERE b.keyid IN (zzzbettrans_KeyIDList)

END
BEGIN--------3) zzzbettransm  --------------------------------------
	
	UPDATE b 
		SET
			RepUpdateTime = SYSDATETIME()
	FROM zzzbettransm b WITH (ROWLOCK, UPDLOCK)
	WHERE b.keyid IN (zzzbettransm_KeyIDList)
END
