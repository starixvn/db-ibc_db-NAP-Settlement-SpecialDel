/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@Max
	Task: Rename column on Ticketvoiding_VoidBetAutomation_Service [Redmine:#175412]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO

EXEC sys.sp_rename 'Ticketvoiding_VoidBetAutomation_Service.VoidingHistory ', 'VoidingHistoryId';