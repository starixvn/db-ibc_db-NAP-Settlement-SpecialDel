/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/
USE msdb ;  
GO  
  
EXEC dbo.sp_update_jobstep  
    @job_name = N'bodb_CustomerLog: NAP Settlement Performance Report', 
	@step_id = 1,
    @database_name = 'bodb_CustomerLog_Archive'
GO 