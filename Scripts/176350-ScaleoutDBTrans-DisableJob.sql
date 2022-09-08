/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
USE [msdb]
GO
EXEC  msdb.dbo.sp_stop_job N'bodb02 : Task_BalanceUpdBonusCredit' ;  

EXEC msdb.dbo.sp_update_job @job_name=N'bodb02 : Task_BalanceUpdBonusCredit', 
		@enabled=0
GO

EXEC  msdb.dbo.sp_stop_job N'bodb02: Bonus - Adjustment Transfer' ;  
GO
EXEC msdb.dbo.sp_update_job @job_name=N'bodb02: Bonus - Adjustment Transfer', 
		@enabled=0
GO