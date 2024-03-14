/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	 Created: 20240118@Louisa
	Task: VS4-Cock Fighting [Redmine: #199700]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81050 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS)
	VALUES ( 81050, 'NAP_Admin_Settlement_s178', 'Calculate All VS4', N'全部计算')

GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81051 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS)
	VALUES ( 81051, 'NAP_Admin_Settlement_s178', 'Refund All VS4', N'全部退款')

GO
