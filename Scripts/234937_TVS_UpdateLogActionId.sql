/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
/*
	Created: 20251119@Lani
	Task: [TVS] Manage Remark - New function to remark issue of matches [Redmine: #234937]
	DB: DBLOG/bodb_CustomerLog
*/
USE [bodb_CustomerLog]
GO

UPDATE b
SET b.SPName = 'TicketVoiding_Remark_Insert'
   ,b.ActionNameEN = 'Insert remark'
   ,b.IsInternal = 0
   ,b.ActionNameCH = 'Insert remark'
FROM dbo.LogAction AS b WITH (UPDLOCK, ROWLOCK)
WHERE b.ActionId = 90506;


UPDATE b
SET b.SPName = 'TicketVoiding_Remark_Update'
   ,b.ActionNameEN = 'Update remark'
   ,b.IsInternal = 0
   ,b.ActionNameCH = 'Update remark'
FROM dbo.LogAction AS b WITH (UPDLOCK, ROWLOCK)
WHERE b.ActionId = 90507;