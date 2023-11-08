/*<info serverAlias="DBTXN-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date 20210107
	Task:  - [Redmine: 196593]
	DB: DBTXN/bodb02
	
*/ 
-- run on sitedb1 and dbtrans, waiting for step 1,2,3,4 done
UPDATE t
	SET CreatedDate = '2023-11-07'
FROM TicketVoiding_RoutineTasks t WITH (ROWLOCK,UPDLOCK)
WHERE StepNo IN (5,6,7,8) AND [Status] = 0
GO
