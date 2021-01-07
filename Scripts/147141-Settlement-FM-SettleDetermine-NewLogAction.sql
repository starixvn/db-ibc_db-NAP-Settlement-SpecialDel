/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20210111@Kathy
	Task :Insert new logaction [Redmine:#147141]
	DB: DBLOG/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81024)
BEGIN
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81024, 'Change Suspend Time', 'NAP_Set_FastMarket_ResultDetailUpd')
END
GO