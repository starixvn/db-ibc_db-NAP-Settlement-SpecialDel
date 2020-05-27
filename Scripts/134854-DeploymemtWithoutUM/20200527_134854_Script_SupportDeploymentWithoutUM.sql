/*<info serverAlias="DBTXN-msdb" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/
/* 
	Created:20200527@Helen
    Task: 
    DB: dbtrans/bodb02 - https://nexdev.net/issues/134854
	
	Revisions:
		- 20200527@Helen:support deploy without UM - [Redmine:134854]
*/
EXEC msdb.dbo.sp_update_jobstep 
		--@job_id=N'58236f0d-fe07-46c2-a656-10af501db069'
		@job_name = 'bodb02 : TicketVoiding - VoidBets Automation' , @step_id=3 , 
		@command=N'DECLARE @Delay VARCHAR(100) = ''''
SET @Delay = dbo.f_Job_SetWaitforDelay () 
WAITFOR DELAY @Delay '
GO
