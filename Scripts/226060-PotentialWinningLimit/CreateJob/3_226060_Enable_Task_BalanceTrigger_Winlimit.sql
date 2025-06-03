/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*	
	Created: 20250416@Louisa
	Task:  Potential Winning Limit/Threshold [Redmine:#226060]
	DB: DBSIC/bodb02
	
	Revisions:
		- 20250416@Louisa:  init new setting on SystemSetting [Redmine:#226060]

*/


-- Enable the job
EXEC msdb.dbo.sp_update_job  
    @job_name=N'bodb02: Task_BalanceTrigger_WinLimit',  
    @enabled = 1;  

-- Start the job
EXEC msdb.dbo.sp_start_job  
    @job_name=N'bodb02: Task_BalanceTrigger_WinLimit';