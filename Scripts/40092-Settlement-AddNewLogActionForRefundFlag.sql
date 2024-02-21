/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: Kathy
	Date: 20200821
	Task : Add new logaction
	DB: DBLOG/bodb_CustomerLog

*/
USE bodb_CustomerLog
GO
IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.LogAction WHERE ActionId = 81018 )
	INSERT INTO dbo.LogAction (ActionID, SPName, ActionNameEN) VALUES (81018, 'NAP_Set_SettlementStatusUpd', 'Turn On/Off Refund')

GO



