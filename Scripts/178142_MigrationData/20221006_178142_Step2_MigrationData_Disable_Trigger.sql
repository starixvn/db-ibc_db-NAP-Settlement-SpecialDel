/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Disable Trigger
    DB: DBSIG-bodb02

	 Revisions:
		- 20220926@Victoria: Disable Trigger for bettransX tables [Redmineid:#178142] 
*/

	DISABLE TRIGGER ALL ON bettrans
	GO
	DISABLE TRIGGER ALL ON bettransG
	GO
	DISABLE TRIGGER ALL ON BettransInfo
	GO
	DISABLE TRIGGER ALL ON bettransLC
	GO
	DISABLE TRIGGER ALL ON bettransm
	GO
	DISABLE TRIGGER ALL ON bettransRnG
	GO
	DISABLE TRIGGER ALL ON translog
	GO
	DISABLE TRIGGER ALL ON balanceTable_tmp
	GO

