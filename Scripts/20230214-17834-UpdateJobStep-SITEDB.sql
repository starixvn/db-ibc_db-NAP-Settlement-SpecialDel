/*<info serverAlias="DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/   
/*	
	Created: 20221003@Max
    Task: [TVS] Enhance archive process of TVS data regarding the Scale Out DB project - [Redmine: #178234]

	DB: DBSIG/msdb - DBCTG/msdb
*/
USE [msdb]
GO

BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0

EXEC @ReturnCode = msdb.dbo.sp_update_jobstep @job_name = 'bodb02: NAP Task delete settled match in queue',
		@step_id=4, 
		@on_success_action=3
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

EXEC @ReturnCode = msdb.dbo.sp_update_job @job_name = 'bodb02: NAP Task delete settled match in queue', @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

    
