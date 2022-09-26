/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20220926@Victoria
    Task: Data Migration - Enable Trigger
    DB: DBSIG-bodb02

	 Revisions:
		- 20220926@Victoria: Enable Trigger for bettransX tables [Redmineid:#178142] 
*/

	ENABLE TRIGGER ALL ON bettrans
	GO
	ENABLE TRIGGER ALL ON bettransG
	GO
	ENABLE TRIGGER ALL ON BettransInfo
	GO
	ENABLE TRIGGER ALL ON bettransLC
	GO
	ENABLE TRIGGER ALL ON bettransm
	GO
	ENABLE TRIGGER ALL ON bettransRnG
	GO
	ENABLE TRIGGER ALL ON translog
	GO
	ENABLE TRIGGER ALL ON balanceTable_tmp
	GO

