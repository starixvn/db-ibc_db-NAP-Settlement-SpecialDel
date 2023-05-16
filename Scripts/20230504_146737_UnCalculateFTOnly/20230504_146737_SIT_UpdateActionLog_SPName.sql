/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20230504@Aries
	Task: Un-calculate FT Only [Redmine: #146737]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO


IF EXISTS (SELECT 1 FROM LogAction WHERE ActionID in (81040))
BEGIN
    UPDATE LogAction
	SET SPName = 'NAP_Admin_Settlement_1' 
	WHERE ActionID = 81040
END


