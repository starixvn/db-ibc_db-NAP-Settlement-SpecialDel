/*<info serverAlias="DBSIG-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220808@Max
	Task: Disable Notification Step in job vndba:Check slowly parlay settlement - [Redmine:#175412]  
	DB: DBSIG-msdb
*/

USE [msdb]
GO
 
DECLARE @step_id INT = 0

SELECT @step_id = b.step_id
FROM msdb.dbo.sysjobs a
INNER JOIN msdb.dbo.sysjobsteps b
ON a.job_id = b.job_id
WHERE a.name = 'vndba:Check slowly parlay settlement'
	AND b.step_name = 'check autovoid queue'

EXEC msdb.dbo.sp_update_jobstep @job_name=N'vndba:Check slowly parlay settlement',
		@step_id=@step_id, 
		@command='--EXEC TicketVoiding_AutoVoid_Notification_Job'
GO


