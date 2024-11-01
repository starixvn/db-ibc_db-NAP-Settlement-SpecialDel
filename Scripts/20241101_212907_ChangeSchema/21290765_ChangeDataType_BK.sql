/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241101@Aries
	Task:  Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]
	DB: DBARC-bodb_Archive

	Revision:
		- 20241101@Aries: Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]

*/
USE bodb_Archive
ALTER TABLE ResultDetail_BK ALTER COLUMN LastModifyDate  DATETIME;
