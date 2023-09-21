/*<info serverAlias="DBCTG-msdb" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230919@July
	Task: Delete job  [Redmine:#193701]  
	DB: DBCTG-msdb
		   
*/
USE [msdb]
GO
EXEC msdb.dbo.sp_delete_job @job_name=N'bodb02: Ticket Voiding - Disabled', @delete_unused_schedule=1
GO
EXEC msdb.dbo.sp_delete_job @job_name=N'bodb02 : TicketVoiding - VoidBets Automation - Disabled', @delete_unused_schedule=1
GO

