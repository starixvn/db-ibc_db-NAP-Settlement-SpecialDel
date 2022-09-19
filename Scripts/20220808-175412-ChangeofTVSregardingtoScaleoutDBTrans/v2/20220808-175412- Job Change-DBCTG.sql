/*<info serverAlias="DBCTG-msdb" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220808@Max
	Task: Disable Job - [Redmine:#175412]  
	DB: DBCTG-msdb
*/

USE [msdb]
GO
----------DISABLE 2 TICKETVOIDING JOB-------------------
EXEC dbo.sp_stop_job @job_name = N'bodb02 : TicketVoiding - VoidBets Automation';
GO
EXEC dbo.sp_update_job  
    @job_name = N'bodb02 : TicketVoiding - VoidBets Automation',  
    @new_name = N'bodb02 : TicketVoiding - VoidBets Automation - Disabled', 
    @enabled = 0 ;  
GO  

EXEC dbo.sp_stop_job @job_name = N'bodb02: Ticket Voiding';
GO
EXEC dbo.sp_update_job  
    @job_name = N'bodb02: Ticket Voiding',  
    @new_name = N'bodb02: Ticket Voiding - Disabled', 
    @enabled = 0 ;  
GO 


