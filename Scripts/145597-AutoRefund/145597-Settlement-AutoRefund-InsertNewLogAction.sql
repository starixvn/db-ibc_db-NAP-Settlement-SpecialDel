/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
	Created by: 20201223@Louisa
	Task : Insert new LogAction 81022, 81023 for Auto Refund [Redmine:#145597]
	DB: DBLOG/bodb_CustomerLog 

*/

USE bodb_CustomerLog
GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81022 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCH	)
	VALUES ( 81022, 'Admin_Settlement_Refund_All_Push', 'Auto Refund Single'	  , 'Auto Refund Single' )

GO

	IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81023 )
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCH	)
	VALUES( 81023, 'NAP_Admin_Settlement_Refund_MP_Push', 'Auto Refund Parlay'	  , 'Auto Refund Parlay' )

GO



