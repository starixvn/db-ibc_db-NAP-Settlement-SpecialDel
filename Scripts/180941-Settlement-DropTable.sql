/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
USE bodb_CustomerLog
GO

-- drop table
drop table Single_Calculate_Queue_bk_deleted
GO
drop table Parlay_Calculate_Queue_bk_deleted
GO
drop table SettlementPerformanceLog_deleted
GO

-- drop sp
drop procedure NAP_Set_QueueSBBackup_deleted
