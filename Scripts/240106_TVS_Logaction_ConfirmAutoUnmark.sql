/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20250926@July
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 20250926@July:  TVS - some error with mark/unmark ticket [Redmine:#240106]

*/
USE bodb_CustomerLog
GO

BEGIN

	UPDATE LogAction WITH (ROWLOCK, UPDLOCK)
	SET SPName = 'TicketVoiding_AutoUnmark_Update'
	  ,[ActionNameEN]  = 'Confirm Auto Unmark'
	  ,[ActionNameCH]  = 'Confirm Auto Unmark'
	  ,[ActionNameCS]  = 'Confirm Auto Unmark'
	  ,ActionNameJP  = 'Confirm Auto Unmark'
	  ,ActionNameIT  = 'Confirm Auto Unmark'
	  ,ActionNameTH  = 'Confirm Auto Unmark'
	  ,ActionNameKO  = 'Confirm Auto Unmark'
	  ,ActionNameVI  = 'Confirm Auto Unmark'
	  ,ActionNameCN  = 'Confirm Auto Unmark'
	WHERE ActionId = 90504

END