/*<info serverAlias="DBSIG-msdb" executers="" isFunction="0"></info>*/
/*	
	Created: 20240610@Helen
    Task: Support check data for Max Payout Per Match setting - New Rule - New Job - [Redmine: #206245]
    DB: DBSIG-msdb
    Revisions:
		- 20240610@Helen: Support check data for Max Payout Per Match setting - New Rule - New Job	
		
*/
USE msdb
GO

---stop job 
EXEC dbo.sp_stop_job N'bodb02 : Task Max Payout - Check Data';
GO
EXEC msdb..sp_update_job @job_name = N'bodb02 : Task Max Payout - Check Data', @enabled = 0 --Disable
GO
