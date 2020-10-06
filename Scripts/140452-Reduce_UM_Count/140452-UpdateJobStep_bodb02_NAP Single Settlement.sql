/*<info serverAlias="DBTXN-msdb" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created by:20201005@Louisa
    Task: Reduce UM Count & Write Job History Log Into Disk on NAP Settlement [Redmine:#140452]
    DB: DBTXN/msdb

	Revision:

*/

USE [msdb]
GO


----1. Single Settlement
EXEC sp_update_jobstep @job_name=N'bodb02 : NAP Single Settlement', 
                       @step_id=1, ---- @step_name=N'Call NAP_Admin_Settlement_SB_Job'
                       @command=N'EXEC dbo.NAP_Admin_Settlement_Job  @Jobname = ''bodb02 : NAP Single Settlement''
									,@Waitfordelay = ''00:00:00.280''' 

GO