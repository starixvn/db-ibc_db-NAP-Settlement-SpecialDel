/*<info serverAlias="DBLOG-bodb_CustomerLog_archive" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
/* 
	 Creator: Kathy  
	 Date: 20230308@Kathy  
	 Task: backup data of 2 table single_calculate_queue & parlay_calculate_queue [Redmine:#184726]
	   
	 Revisions:  
		- 20230308@Kathy: create SP [Redmine:#184726]  
		
	 Param's Explanation:  
    
*/ 

USE bodb_CustomerLog_archive
GO
ALTER TABLE Single_Calculate_Queue_bk ADD SiteDBGroupId SMALLINT
GO

ALTER TABLE Parlay_Calculate_Queue_bk ADD SiteDBGroupId SMALLINT