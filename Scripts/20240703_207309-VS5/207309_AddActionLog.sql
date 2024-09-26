/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: 20231211@Aries
	Task: Auto Payout for Tennis sport using Sofascore provider [Redmine:#196768]
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog

IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81053 )
BEGIN
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS)
	VALUES ( 81053, 'NAP_Admin_Settlement_VS5', 'Calculate All VS5', N'全部计算')
END 

IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81054)
BEGIN
	INSERT INTO dbo.LogAction	(ActionID, SPName, ActionNameEN, ActionNameCS)
	VALUES ( 81054, 'NAP_Admin_Settlement_VS5', 'Refund All VS5', N'全部退款')
END
