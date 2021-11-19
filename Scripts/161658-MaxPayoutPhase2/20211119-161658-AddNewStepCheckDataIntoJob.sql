/*<info serverAlias="DBTXN-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20211119@Tina
	Task: Check data for Max payout per match/bettype - [Redmine: #161658]
	DB: DBTRANS-msdb
*/

DECLARE @ReturnCode INT
SELECT @ReturnCode = 0


/****** Object:  Step [Check data for Max payout per Match/Bettype]    Script Date: 11/19/2021 10:28:52 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_name=N'vndba:Check slowly parlay settlement', @step_name=N'Check data for Max payout per Match/Bettype', 
		@step_id=9, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC dbo.Nap_Admin_CustLimitBet_CheckData_Notification_Job', 
		@database_name=N'bodb02', 
		@flags=0

