/*<info serverAlias="DBLOG-bodb_CustomerLog" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20250708@July
    DB: DBLOG/bodb_CustomerLog 
    
    Revisions:            
		- 20250708@July:  Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

*/
USE bodb_CustomerLog
GO

BEGIN

	INSERT INTO LogAction
	(
		[ActionID]		
		,[SPName]		
		,[ActionNameEN]
		,[ActionNameCH]
		,[ActionNameCS]
		,ActionNameJP,ActionNameIT,ActionNameTH,ActionNameKO,ActionNameVI,ActionNameCN
	)
	VALUES ( 90999, 'TVS - Agency Cash Service', 'TVS - Agency Cash Service'	 , 'TVS - Agency Cash Service' , 'TVS - Agency Cash Service'
	, 'TVS - Agency Cash Service'
	, 'TVS - Agency Cash Service'
	, 'TVS - Agency Cash Service'
	, 'TVS - Agency Cash Service'
	, 'TVS - Agency Cash Service'
	, 'TVS - Agency Cash Service'
	
	)

END