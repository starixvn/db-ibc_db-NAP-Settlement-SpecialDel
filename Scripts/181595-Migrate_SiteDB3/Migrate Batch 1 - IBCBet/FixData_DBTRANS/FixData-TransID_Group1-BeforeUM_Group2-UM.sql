--Group 2 - In UM - fix data
/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: fix data on sitedb03 [Redmineid:#181595] 

		1) Bettrans
		2) BettransInfo
		3) BettransLC
		4) BettransRnG
		5) bettransG
		6) Translog
		7) Transfer
		8) Transfer_Coll
		9) TransferInfo

*/
----------correct tickets---------------------------------
/* find text and replace by list of wrong recommends for table need to fix data
1) Bettrans -> bettrans_TransIDList
2) BettransInfo -> bettransInfo_TransIDList
3) BettransLC -> bettransLC_TransIDList
4) BettransRnG -> bettransRnG_TransIDList
5) bettransG -> bettransG_TransIDList
6) Translog -> Translog_translogidList
7) Transfer -> Transfer_transidList
8) Transfer_Coll -> Transfer_Coll_recommendList
9) TransferInfo -> Transfer_Coll_transidList

*/
BEGIN--------1) bettrans  --------------------------------------

	UPDATE b 
		SET
			[RepUpdateTime]	=SYSDATETIME()
	FROM bettrans b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (bettrans_TransIDList)

END
BEGIN--------2) bettransInfo  --------------------------------------

	UPDATE b	
		SET 
			[RepUpdateTime]	=SYSDATETIME()
	FROM bettransInfo b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (bettransInfo_TransIDList)

END

BEGIN--------3) bettransLC  --------------------------------------

	UPDATE b 
		SET
			[RepUpdateTime]	=SYSDATETIME()
	FROM bettransLC b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (bettransLC_TransIDList)

END

BEGIN-------- 4) BettransRnG  --------------------------------------
	-- inhouse using column Timestamp, already checked with Victor (TW)
	UPDATE b 
		SET
			TransId = b.TransId
	FROM bettransRnG b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (bettransRnG_TransIDList)

END
BEGIN-------- 5) bettransG  --------------------------------------

	UPDATE b 
		SET
			[RepUpdateTime]	= SYSDATETIME()
	FROM bettransG b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (bettransG_TransIDList)

END
BEGIN-------- 6) Translog  --------------------------------------
	-- inhouse using column Timestamp, already checked with Victor (TW)
	UPDATE b 
		SET
			translogid = b.translogid
	FROM Translog b WITH (ROWLOCK, UPDLOCK)
	WHERE b.translogid IN (Translog_translogidList)

END
BEGIN-------- 7) Transfer  --------------------------------------
	UPDATE b 
		SET
			[RepUpdateTime]	= SYSDATETIME()
	FROM Transfer b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (Transfer_transidList)

END
BEGIN-------- 8) Transfer_Coll  --------------------------------------

	UPDATE b 
		SET
			RepUpdateTime = SYSDATETIME()
	FROM Transfer_Coll b WITH (ROWLOCK, UPDLOCK)
	WHERE b.transid IN (Transfer_Coll_transidList)

END

