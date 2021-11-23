/*<info serverAlias="DBTXN-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211119@Tina
	Task: Check data for Max payout per match/bettype - [Redmine: #161658]
	DB: DBTRANS-msdb
*/

USE [msdb]
GO
EXEC msdb.dbo.sp_update_jobstep @job_name=N'vndba:Check slowly parlay settlement',
		@step_id=6, 
		@on_success_action=3 
GO
EXEC msdb.dbo.sp_add_jobstep @job_name=N'vndba:Check slowly parlay settlement', @step_name=N'Check data for Max payout per Match/Bettype', 
		@step_id=7, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.Nap_Admin_CustLimitBet_CheckData_Notification_Job', 
		@database_name=N'bodb02', 
		@flags=0
GO
