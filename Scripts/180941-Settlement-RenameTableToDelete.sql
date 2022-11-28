/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/
USE bodb_CustomerLog
GO

exec sp_rename 'Single_Calculate_Queue_bk', 'Single_Calculate_Queue_bk_deleted'
GO
exec sp_rename 'Parlay_Calculate_Queue_bk', 'Parlay_Calculate_Queue_bk_deleted'
GO
exec sp_rename 'SettlementPerformanceLog', 'SettlementPerformanceLog_deleted'
GO


-- rename sp 
EXEC sp_rename 'NAP_Set_QueueSBBackup', 'NAP_Set_QueueSBBackup_deleted'
