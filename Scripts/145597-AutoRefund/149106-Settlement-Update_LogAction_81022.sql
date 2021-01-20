/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20210120@Louisa
	Task : Update LogAction 81022 [Redmine:#149106]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

	IF EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WITH(NOLOCK) WHERE ActionId = 81022 )
	BEGIN
		UPDATE dbo.LogAction	SET SPName = 'NAP_Admin_Settlement_Refund_All_Push' WHERE ActionId = 81022
	END
GO