/*<info serverAlias="DBTXN-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Max
	Date 20210914
	Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	DB: DBTXN/msdb - Add one more step on the job bodb02: NAP Task delete settled match in queue, calling SP
*/
USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

EXEC @ReturnCode = msdb.dbo.sp_update_jobstep @job_name = 'bodb02: NAP Task delete settled match in queue',
		@step_id=1, 
		@on_success_action=3
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_name = 'bodb02: NAP Task delete settled match in queue', @step_name=N'[NAP_Admin_CustLimitBet_Delete]', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.NAP_Admin_CustLimitBet_Delete', 
		@database_name=N'bodb02', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_name = 'bodb02: NAP Task delete settled match in queue', @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
