/*<info serverAlias="DBLIC-bodb_Licensee,DBLIC_STANDBY-bodb_Licensee" executers="" isFunction="0"></info>*/
/*	
	Created: 20250206@July
    DB: DBLIC-bodb_Licensee,DBLIC_STANDBY-bodb_Licensee
    Revisions:
		- 20250206@July: Disable current job - [Redmine: #216623]
	
	Param's explanation:	
		
*/

USE [msdb]
GO

EXEC dbo.sp_stop_job @job_name = N'bodb_Licensee : ResultAmendment - Task CleanUp data for send OIC';
GO
EXEC dbo.sp_update_job  
    @job_name = N'bodb_Licensee : ResultAmendment - Task CleanUp data for send OIC',  
    @new_name = N'bodb_Licensee : ResultAmendment - Task CleanUp data for send OIC - Disabled', 
    @enabled = 0 ;  
GO 
