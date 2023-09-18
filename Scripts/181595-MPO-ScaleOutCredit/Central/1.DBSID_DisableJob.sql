/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created: 20230918@Max
    Task: Scale out DBTRANS for Credit market - [Redmine: #181595]
    DB: DBCTG/bodb02
    Revisions:
		- 20230712@Max: Stop, Disable current job on DBCTG - [Redmine: #181595]
	
	Param's explanation:	
		
*/

USE [msdb]
GO



--Stop , disable job bodb02 : Task Max Payout Per Match
EXEC msdb.dbo.sp_update_job 
	@job_name = 'bodb02 : Task Max Payout Per Match'  
	,@new_name = 'bodb02 : Task Max Payout Per Match - Disabled'
	,@enabled=0
GO
EXEC dbo.sp_stop_job N'bodb02 : Task Max Payout Per Match - Disabled';
GO



--Stop , disable job bodb02 : Task Retry Max Payout
EXEC msdb.dbo.sp_update_job 
	@job_name = 'bodb02 : Task Retry Max Payout'  
	,@new_name = 'bodb02 : Task Retry Max Payout - Disabled'
	,@enabled=0
GO
EXEC dbo.sp_stop_job N'bodb02 : Task Retry Max Payout - Disabled';
GO