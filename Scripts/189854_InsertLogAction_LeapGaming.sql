/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20230704@Louisa
	Task : Insert new LogAction fro Virtual Leap Gaming - VS3 [Redmine:#189854]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81043 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS	)
	VALUES ( 81043, 'NAP_Admin_Settlement_s178', 'Calculate All'	  , N'全部计算' )

GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81044 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS	)
	VALUES( 81044, 'NAP_Admin_Settlement_s178', 'Refund All'	  , N'全部退款' )

GO