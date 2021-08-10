/*<info serverAlias="DBTXN-msdb" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20210810@Kathy
    Task: grant permission to send email - Bitcoin [Readmine:#159714]
    DB: DBTXN/msdb 
    
    Revisions:            
		- 20210810@Kathy:  grant send email - Bitcoin [Readmine:#159714]

*/
USE msdb;
EXEC msdb.dbo.sp_addrolemember @rolename = 'DatabaseMailUserRole'
    ,@membername = 'dot_intg';
GO
