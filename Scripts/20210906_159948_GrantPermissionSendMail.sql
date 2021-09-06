/*<info serverAlias="DBTXN-msdb" executers="" viewers="" isFunction="0"></info>*/
/*	
	Creator: July
	Date: 20210906
	Task: Grant permission send mail - [Redmine: #159948]
	DB: DBTXN/msdb
*/

USE msdb;
CREATE USER  bodbAdminNet FOR LOGIN  bodbAdminNet; 

EXEC msdb.dbo.sp_addrolemember @rolename = 'DatabaseMailUserRole'
    ,@membername = 'bodbAdminNet';