/*<info serverAlias="DBTXN-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20230712@Kathy
	Task: Extend datatype [Redmine: #187252]
	DB: DBTXN/bodb_CustomerLog

*/
USE bodb_CustomerLog

ALTER TABLE Userlog_Settle ALTER COLUMN Remark VARCHAR(MAX)
GO

