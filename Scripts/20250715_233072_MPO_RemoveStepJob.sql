/*<info serverAlias="DBCTG-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Max
	Date 20250715
	Task: [Synergy] - Remove code check data on DBTRANS - [Redmine: #233072]
	DB: DBCTG-msdb (DBTRANS only)
*/
USE [msdb]
GO

---stop job 
EXEC dbo.sp_stop_job N'vndba:Check slowly running or failed processes';
GO
EXEC sp_update_job @job_name = N'vndba:Check slowly running or failed processes', @enabled = 0
GO

--delete step Check CustLimitBet Queue
DECLARE @step_id INT

SELECT @step_id = step_id
FROM msdb.dbo.sysjobsteps s
	JOIN msdb.dbo.sysjobs j ON s.job_id = j.job_id
WHERE j.name = N'vndba:Check slowly running or failed processes' 
	AND s.step_name = N'Check CustLimitBet Queue'

-- Delete Step
IF @step_id IS NOT NULL
BEGIN
    EXEC msdb.dbo.sp_delete_jobstep
        @job_name = N'vndba:Check slowly running or failed processes' ,
        @step_id = @step_id;
END

--delete step Check data for Max payout per Match/Bettype
SET @step_id = NULL

SELECT @step_id = step_id
FROM msdb.dbo.sysjobsteps s
	JOIN msdb.dbo.sysjobs j ON s.job_id = j.job_id
WHERE j.name = N'vndba:Check slowly running or failed processes' 
	AND s.step_name = N'Check data for Max payout per Match/Bettype'

-- Delete Step
IF @step_id IS NOT NULL
BEGIN
    EXEC msdb.dbo.sp_delete_jobstep
        @job_name = N'vndba:Check slowly running or failed processes' ,
        @step_id = @step_id;
END

--update job step
EXEC msdb.dbo.sp_update_jobstep @job_name = N'vndba:Check slowly running or failed processes',
		@step_id=7, 
		@on_success_action=1

--start job
EXEC msdb.dbo.sp_update_job @job_name = N'vndba:Check slowly running or failed processes', @enabled = 1
GO
EXEC dbo.sp_start_job N'vndba:Check slowly running or failed processes'
GO