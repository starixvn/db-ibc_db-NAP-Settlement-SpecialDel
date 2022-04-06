/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/

USE [msdb]
GO
EXEC msdb.dbo.sp_update_jobstep @job_name=N'bodb02 : NAP Settlement VS BetRadar'
		,@step_id=1
		,@on_success_action=4
		,@on_success_step_id=2
		,@on_fail_action=2
		,@step_name=N'Call NAP_Admin_Settlement_SB_Job'
		,@command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : NAP Settlement VS BetRadar'' , @Waitfordelay = ''00:00:00.280'''
GO

EXEC msdb.dbo.sp_update_jobstep @job_name=N'bodb02 : NAP Settlement VS BetRadar'
		,@step_id=2 
		,@on_success_action=4
		,@on_success_step_id=1
		,@on_fail_action=2 
		,@step_name=N'delay 280ms'
		,@command=N'WAITFOR DELAY ''00:00:00.280'''
GO

EXEC msdb.dbo.sp_delete_jobstep  @job_name=N'bodb02 : NAP Settlement VS BetRadar'
		,@step_id = 3 ;
GO  


EXEC msdb.dbo.sp_delete_jobstep  @job_name=N'bodb02 : NAP Settlement VS BetRadar'
		,@step_id = 3 ;
GO  


