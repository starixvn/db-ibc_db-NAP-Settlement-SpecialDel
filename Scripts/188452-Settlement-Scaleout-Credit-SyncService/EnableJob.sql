/*<info serverAlias="DBSIC-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
USE msdb
GO
-- sitedb3
DECLARE @jobName NVARCHAR(128) = 'bodb02: NAP Task delete settled match in queue';

EXEC dbo.sp_update_job
    @job_name = @jobName,
    @enabled = 1;
	
EXEC dbo.sp_start_job
    @job_name = @jobName;
	
GO


DECLARE @jobName NVARCHAR(128) = 'vndba:Check slowly BalanceUpdCreditSports process';

EXEC dbo.sp_update_job
    @job_name = @jobName,
    @enabled = 1;
	
EXEC dbo.sp_start_job
    @job_name = @jobName;
	
GO


DECLARE @jobName NVARCHAR(128) = 'vndba:Check slowly running or failed processes';

EXEC dbo.sp_update_job
    @job_name = @jobName,
    @enabled = 1;
	
EXEC dbo.sp_start_job
    @job_name = @jobName;
	
GO

DECLARE @jobName NVARCHAR(128) = 'bodb02 - daily check TempVariableNumber time out';

EXEC dbo.sp_update_job
    @job_name = @jobName,
    @enabled = 1;
	
EXEC dbo.sp_start_job
    @job_name = @jobName;
	
GO
	