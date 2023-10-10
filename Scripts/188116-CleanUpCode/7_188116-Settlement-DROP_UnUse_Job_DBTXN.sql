/*<info serverAlias="DBTXN-bodb02,DBTXN-msdb" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20231004@louisa
	Task: DROP un-used objects  [Redmine:#188116]  
	DB: DBTXN-bodb02,DBTXN-msdb
	
*/


USE bodb02
GO

DROP PROCEDURE Task_Calculate_Parlay
GO

USE msdb
GO
	IF EXISTS (SELECT TOP 1 1 FROM dbo.sysjobs s WHERE s.name = N'bodb02 : Parlay Settlement Task')  
	BEGIN
		EXEC dbo.sp_stop_job  @job_name = N'bodb02 : Parlay Settlement Task'
		 
		EXEC dbo.sp_delete_job @job_name = N'bodb02 : Parlay Settlement Task', @delete_unused_schedule=1
	END
GO