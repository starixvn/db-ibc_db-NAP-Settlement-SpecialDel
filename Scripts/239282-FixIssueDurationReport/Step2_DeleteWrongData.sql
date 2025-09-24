/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="wsv_nap" viewers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250918@Max
	DB: DBLOG-DB054bodb_CustomerLog_Archive
	Task: Fix the issue where the daily KPI report for Soccer sent incorrect data on Sep 17 [Redmine: #239282]

*/

USE bodb_CustomerLog_Archive
GO

DELETE s
FROM dbo.SettlementPerformanceLog s
WHERE CAST(s.Starttime AS DATE) = '2025-09-17'
		