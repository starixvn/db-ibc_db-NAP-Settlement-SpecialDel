/*<info serverAlias="DBSIG-msdb" executers="" isFunction="0"></info>*/
/*	
	Created: 20240610@Helen
    Task: Support check data for Max Payout Per Match setting - New Rule - New Job - [Redmine: #206245]
    DB: DBSIG-msdb
    Revisions:
		- 20240610@Helen: rename job

	Param's explanation:		
		
*/
USE msdb
GO

---stop job 
EXEC dbo.sp_stop_job N'bodb02 : Task Max Payout - Check Data';
GO

EXEC sp_update_job @job_name = N'bodb02 : Task Max Payout - Check Data', @enabled = 0
GO

--rename
EXEC dbo.sp_update_job
    @job_name = N'bodb02 : Task Max Payout - Check Data',
    @new_name = N'bodb02 : Detect Data Consistency - Max Turnover/Payout'
GO

--start job
EXEC msdb..sp_update_job @job_name = N'bodb02 : Detect Data Consistency - Max Turnover/Payout', @enabled = 1
GO
EXEC dbo.sp_start_job N'bodb02 : Detect Data Consistency - Max Turnover/Payout'
GO





