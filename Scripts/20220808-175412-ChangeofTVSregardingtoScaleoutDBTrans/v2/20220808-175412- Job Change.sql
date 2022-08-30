/*<info serverAlias="DBCTG-msdb,DBSIG-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220808@Max
	Task: Disable Job - [Redmine:#175412]  
	DB: DBCTG-msdb, DBSIG-msdb
*/

USE [msdb]
GO
----------DISABLE 2 TICKETVOIDING JOB-------------------
EXEC dbo.sp_update_job  
    @job_name = N'bodb02 : TicketVoiding - VoidBets Automation',  
    @new_name = N'bodb02 : TicketVoiding - VoidBets Automation - Disabled', 
    @enabled = 0 ;  
GO  

EXEC dbo.sp_update_job  
    @job_name = N'bodb02: Ticket Voiding',  
    @new_name = N'bodb02: Ticket Voiding - Disabled', 
    @enabled = 0 ;  
GO 

--------REMOVE JOB STEP-----------------------
DECLARE @step_id INT = 0

SELECT @step_id = b.step_id
FROM msdb.dbo.sysjobs a
INNER JOIN msdb.dbo.sysjobsteps b
ON a.job_id = b.job_id
WHERE a.name = 'vndba:Check slowly parlay settlement'
	AND b.step_name = 'check autovoid queue'

EXEC dbo.sp_delete_jobstep  
    @job_name = N'vndba:Check slowly parlay settlement',  
    @step_id = @step_id ; 
GO 

