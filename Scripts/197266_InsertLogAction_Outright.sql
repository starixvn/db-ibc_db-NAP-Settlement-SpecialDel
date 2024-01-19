/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20231201@Kathy
	Task : Insert new LogAction [Redmine:#197266]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81047 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN)
	VALUES ( 81047, 'NAP_Admin_Settlement_Outright', 'Hide Outright Settlement' )

GO

