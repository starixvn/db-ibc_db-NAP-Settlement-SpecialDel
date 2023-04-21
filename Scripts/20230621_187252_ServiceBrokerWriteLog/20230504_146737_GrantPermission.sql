/*<info serverAlias="DBTXN-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20230421@Aries
	Task: Use Service Broker to Write Log to DB Log [Redmine: #187252]
	DB: DBTXN/bodb_CustomerLog

*/
USE bodb_CustomerLog
GRANT RECEIVE ON [dbo].[Queue_UserLog] TO [bodbAdminNet] AS [dbo]
GO
GRANT RECEIVE ON [dbo].[Queue_UserLog] TO [Dot_Admin] AS [dbo]
GO
GRANT RECEIVE ON [dbo].[Queue_UserLog] TO [Dot_CoreAPI] AS [dbo]
GO
GRANT RECEIVE ON [dbo].[Queue_UserLog] TO [Dot_Casino] AS [dbo]
GO


