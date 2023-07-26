/*<info serverAlias="DBSID-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created: 20230712@Max
    Task: Scale out DBTRANS for Credit market - [Redmine: #181595]
    DB: DBSID/bodb02
    Revisions:
		- 20230712@Max: Stop, Disable current job on DBSID - [Redmine: #181595]
	
	Param's explanation:	
		
*/

USE [msdb]
GO



--Stop , disable job bodb02 : Task Max Payout Per Match
EXEC msdb.dbo.sp_update_job 
	@job_name = 'bodb02 : Task Max Payout Per Match'  
	,@new_name = 'bodb02 : Task Max Payout Per Match - Delete'
	,@enabled=0
GO
EXEC dbo.sp_stop_job N'bodb02 : Task Max Payout Per Match - Delete';
GO



--Stop , disable job bodb02 : Task Retry Max Payout
EXEC msdb.dbo.sp_update_job 
	@job_name = 'bodb02 : Task Retry Max Payout'  
	,@new_name = 'bodb02 : Task Retry Max Payout - Delete'
	,@enabled=0
GO
EXEC dbo.sp_stop_job N'bodb02 : Task Retry Max Payout - Delete';
GO