/*<info serverAlias="DBLOG-bodb_CustomerLog,DBTXN-bodb_CustomerLog" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
USE bodb_CustomerLog
GO

ALTER TABLE dbo.UserLog_Settle ADD BroadcastSessionId VARCHAR(50)