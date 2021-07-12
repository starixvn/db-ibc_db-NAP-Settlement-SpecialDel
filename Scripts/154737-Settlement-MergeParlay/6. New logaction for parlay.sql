/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20210701@Kathy
	Task :Insert new logaction
	DB: DBLOG/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO

IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81028)
BEGIN
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81028, 'Calculate Parlay', 'NAP_Admin_Settlement_Profile_Parlay')
END

IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81029)
BEGIN
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81029, 'Refund Parlay', 'NAP_Admin_Settlement_Profile_Parlay')
END

IF NOT EXISTS (SELECT * FROM dbo.LogAction WITH(NOLOCK) WHERE ActionID = 81030)
BEGIN
	INSERT INTO dbo.LogAction (ActionID, ActionNameEN, SPName) VALUES (81030, 'Undo Parlay', 'NAP_Admin_Settlement_Profile_Parlay')
END
GO