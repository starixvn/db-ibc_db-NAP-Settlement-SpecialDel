/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: Hughie.Pham
	Date: 20250121
	Task : Add new logaction [Redmine:#216004]
	DB: DBLOG/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO
INSERT INTO dbo.LogAction (ActionID, SPName, ActionNameEN, ActionNameCH, ActionNameCS, ActionNameJP, ActionNameTH, ActionNameKO, ActionNameVI,IsInternal) 
VALUES (81059, 
		'NAP_Set_ExternalResultDetailUpd', 
		'Settlement - Save Trader Score',
		'',
		'',
		'',
		'',
		'',
		'',
		0
		)
GO