/*<info serverAlias="DBLOG-bodb_CustomerLog_archive" executers="" viewers="" isFunction="0"></info>*/
/*
    Created: 20230414@Aries
	Task: Support OST Team Query Resettlement Log Redmine: #185964
	DB: DBLOG/bodb_CustomerLog,DBLOG/bodb_CustomerLog_archive

*/
USE bodb_CustomerLog_archive
GO
GRANT SELECT ON [dbo].[f_Set_MajorRound] TO [bodbAdminNet]
GO
