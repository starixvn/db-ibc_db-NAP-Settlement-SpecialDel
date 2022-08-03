/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
   Created:20220629@Louisa
   Task: Scale Out BetTrans [Redmine:#175251]

   DB: DBTRANS/bodb02, SiteDB/bodb02
	
	Revisions:
		- 20220719@Louisa: Add column SessionId into table Single_Calculate_Queue [Redmine:#175251]
	
	Param's Explanation: 
		Run on DBTRANS/bodb02 and All SiteDB

*/

USE bodb02
GO

BEGIN
	IF NOT EXISTS ( SELECT TOP 1 1
					FROM sys.columns c 
						INNER JOIN sys.objects o 
							ON c.object_id = o.object_id
					WHERE c.name = 'BroadcastSessionId'
						AND o.name = 'Single_Calculate_Queue'
					)
	ALTER TABLE Single_Calculate_Queue ADD BroadcastSessionId VARCHAR(50)
END
GO