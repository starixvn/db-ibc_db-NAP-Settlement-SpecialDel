/*<info serverAlias="DBPRO-bodb02" executers="" viewers="" isFunction="0"></info>*//*
	Created: Tina@20220425
	Task: Update Match Event Status of a Cricket Child Match to Completed [Redmine: #171935]
	DB: DBPRO/bodb02
*/
USE bodb02GOUPDATE dbo.match WITH (ROWLOCK,UPDLOCK)	SET eventstatus = N'completed'WHERE matchid = 52708928