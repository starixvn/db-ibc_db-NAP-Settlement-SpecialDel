/*<info serverAlias="DBCTG-msdb" executers="" viewers="" isFunction="0"></info>*/
USE [msdb]
GO

EXEC msdb.dbo.sp_delete_job @job_name=N'bodb02: NAP NG2 Settlement', @delete_unused_schedule=1
GO


EXEC msdb.dbo.sp_delete_job @job_name=N'bodb02: NAP NG2 Delete bettrans_staging', @delete_unused_schedule=1
GO
