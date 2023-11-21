/*<info serverAlias="DBTXN-msdb" executers="" isFunction="0"></info>*/
/*
    Created: 20231016@Aries  
	Task: Auto Send Announcement When Refund VS [Redmine:#195333]
	DB: DBTXN/msdb
*/
 
USE [msdb]
GO
EXEC sp_update_job @job_name = N'bodb02 : NAP Settlement VS BetRadar', @enabled = 1
GO
EXEC sp_start_job  @job_name = N'bodb02 : NAP Settlement VS BetRadar' ;  