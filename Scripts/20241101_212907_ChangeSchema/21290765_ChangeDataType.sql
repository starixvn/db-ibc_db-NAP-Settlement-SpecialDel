/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20241101@Aries
	Task:  Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]
	DB: DBPRO-bodb02

	Revision:
		- 20241101@Aries: Enhance Waiting time for the LastModifyDate column of ResultDetail table [Redmine:#212907]

*/
USE bodb02
ALTER TABLE ResultDetail ALTER COLUMN LastModifyDate  DATETIME;
ALTER TABLE ResultDetail14 ALTER COLUMN LastModifyDate  DATETIME;