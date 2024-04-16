/*<info serverAlias="DBBAH-bodb02" executers="" viewers="" isFunction="0" isNested="0"></info>*/
/*
    Created: 20230810@Louisa
	Task: Cleanup un-use objects for Settlement [Redmine: #188116]
	DB: DBBAH-bodb02
*/


USE msdb 
GO  

	IF EXISTS (SELECT TOP 1 1 FROM dbo.sysjobs s WHERE s.name = N'bodb02 : Task_SiteDB_BalanceTrigger_Sync')  
	BEGIN
		EXEC sp_delete_job  
			@job_name = N'bodb02 : Task_SiteDB_BalanceTrigger_Sync' 
	END
GO  
----------------------------------------------------------------------
	
USE bodb02
GO


DROP PROCEDURE IF EXISTS Task_BalanceRecord_SiteDBBalanceTrigger_Insert;
GO

DROP PROCEDURE IF EXISTS SiteDBBalanceTrigger_Insert
GO

 