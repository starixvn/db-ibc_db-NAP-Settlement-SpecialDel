/*<info serverAlias="SBSETTLE-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [msdb]
GO

/*  Created: Kathy@20220107
	Task: monitor Settlement log [Redmine:#167193]
	DB: SBSETTLE-bodb02
*/
EXEC msdb.dbo.sp_add_jobstep @job_name=N'bodb02: Check Settlement status', @step_name=N'Check CalculationLogs', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.DBA_CheckSSBCalculationLog @MonitorDurationWithInMin = 5', 
		@database_name=N'bodb02', 
		@flags=0


