/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: July
	Date: 20211011
	Task : Add new logaction
	DB: DBLOG/bodb_CustomerLog
*/
USE bodb_CustomerLog
GO
INSERT INTO dbo.LogAction (ActionID, SPName, ActionNameEN, ActionNameCH, ActionNameCS, ActionNameJP, ActionNameTH, ActionNameKO, ActionNameVI,IsInternal) 
VALUES (90004, 
		'TicketVoiding_ABWhiteList_Insert', 
		'Insert AB White List',
		'Insert AB White List',
		'Insert AB White List',
		'Insert AB White List',
		'Insert AB White List',
		'Insert AB White List',
		'Insert AB White List',
		0
		),
	(90005, 
		'TicketVoiding_ABWhiteList_Update', 
		'Remove AB White List',
		'Remove AB White List',
		'Remove AB White List',
		'Remove AB White List',
		'Remove AB White List',
		'Remove AB White List',
		'Remove AB White List',
		0
		)



GO