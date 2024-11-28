/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	 Created: 20241031@Louisa
	Task:  VS6-Virtual Basketball [Redmine:#210733]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81055 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS)
	VALUES ( 81055, 'NAP_Admin_Settlement_VS6', 'Calculate VS6', N'全部计算')

GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81056 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS)
	VALUES ( 81056, 'NAP_Admin_Settlement_VS6', 'Refund VS6', N'全部退款')

GO
