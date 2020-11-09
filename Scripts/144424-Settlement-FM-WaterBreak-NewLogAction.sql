/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20201110@Kathy
	Task :Insert new logaction [Redmine:#144424]
	DB: DBLOG/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81020)
BEGIN
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81020, 'Change Water Break', 'NAP_Set_FastMarket_ResultDetailUpd')
END
GO