/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [msdb]
GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'bodb02: NAP Task delete settled match in queue', @step_name=N'Delete SiteDB_SettlementService_LastLog', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.SiteDB_NAP_SettlementService_CalculationLogDel', 
		@database_name=N'bodb02', 
		@flags=0

GO

EXEC msdb.dbo.sp_add_jobstep @job_name=N'vndba:Check slowly parlay settlement', @step_name=N'Check SiteDB_SettlementService_LastLog', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=3, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.SiteDB_NAP_SettlementService_LongRunning', 
		@database_name=N'bodb02', 
		@flags=0