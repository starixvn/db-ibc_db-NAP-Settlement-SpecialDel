/*<info serverAlias="DBSIC-msdb" executers="" isFunction="0" isNested="0"></info>*/
/*
	Created: 20250805@Louisa	
	Task: Cleanup data
	DB: 
	
	Revisions:
		- 20250805@Louisa: Created [RedmineID: #235249]

	Example:			
*/
USE [msdb]
GO
EXEC msdb.dbo.sp_add_jobstep 
		@job_name=N'bodb02: NAP Task delete settled match in queue',
		@step_name=N'Delete CustWinLimitBet_History_Del_InHouse', 
		@step_id=5, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'exec CustWinLimitBet_History_Del_InHouse_Delete @Day = 7', 
		@database_name=N'bodb02', 
		@flags=0
GO
