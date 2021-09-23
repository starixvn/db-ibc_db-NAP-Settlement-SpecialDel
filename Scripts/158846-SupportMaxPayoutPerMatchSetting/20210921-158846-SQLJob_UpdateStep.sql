/*<info serverAlias="DBTXN-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Max
	Date 20210921
	Task: [TVS] Support Max Payout Per Match setting - [Redmine: #158846]
	DB: DBTXN/msdb - Update Job bodb02 : Task Max Payout Per Match, exec via NAP_Admin_Settlement_Job for deploy Non-UM
*/

USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

EXEC @ReturnCode = msdb.dbo.sp_update_jobstep @job_name = 'bodb02 : Task Max Payout Per Match',
		@step_id=1, 
		@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : Task Max Payout Per Match''
									,@Waitfordelay = ''00:00:00.280'''
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_jobstep @job_name = 'bodb02 : Task Max Payout Per Match',
		@step_id=2, 
		@command=N'WAITFOR DELAY ''00:00:00.280''' 
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_name = 'bodb02 : Task Max Payout Per Match', @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO
