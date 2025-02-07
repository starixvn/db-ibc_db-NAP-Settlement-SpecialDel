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

EXEC msdb.dbo.sp_delete_job @job_name=N'bodb_Licensee : ResultAmendment - Task CleanUp data for send OIC - Disabled', @delete_unused_schedule=1
GO
