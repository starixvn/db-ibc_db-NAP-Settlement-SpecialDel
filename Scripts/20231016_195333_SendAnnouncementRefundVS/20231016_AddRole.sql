/*<info serverAlias="DBTXN-msdb" executers="" isFunction="0"></info>*/
/*
    Created: 20231016@Aries  
	Task: Auto Send Announcement When Refund VS [Redmine:#195333]
	DB: DBTXN/msdb
*/
 
USE [msdb]
GO
EXEC sp_addrolemember 'DatabaseMailUserRole', 'bodbAdminNet'