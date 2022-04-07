/*<info serverAlias="DBTXN-bodb02" executers="" selectors="" viewers="" isFunction="0" isNested="0"></info>*/


USE [msdb]
GO
declare @schedule_id int

select @schedule_id = s.schedule_id
from sysjobs j
	inner join sysjobschedules s
		on j.job_id = s.job_id
where j.name = 'bodb02 : TicketVoiding - VoidBets Automation'

EXEC msdb.dbo.sp_update_schedule  @schedule_id=@schedule_id, @new_name=N'Every 10 Seconds', @freq_subday_interval=10
GO


EXEC msdb.dbo.sp_update_jobstep @job_name=N'bodb02 : TicketVoiding - VoidBets Automation', @step_id=4 , 
		@on_success_action=1
GO
