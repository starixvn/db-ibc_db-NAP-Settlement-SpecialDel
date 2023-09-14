/*<info serverAlias="DBTXN-bodb_customerlog,DBLOG-bodb_customerlog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created : Kathy
	Task	: Add new column [Redmine:#192311]
	DB: DBTXN-bodb_customerlog,DBLOG-bodb_customerlog
*/
USE bodb_customerlog
GO

ALTER TABLE [dbo].[UserLog_Settle] ADD BroadcastSessionId VARCHAR(50)
GO

