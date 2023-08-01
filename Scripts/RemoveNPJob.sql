/*<info serverAlias="DBSIC-msdb" executers="" viewers="" isFunction="0"></info>*/
USE [msdb]
GO
--DBSIC-msdb
EXEC msdb.dbo.sp_delete_job @job_name=N'bodb02 : NetPosition tables Archive', @delete_unused_schedule=1
GO
