/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@July
	Task: Add new column  [Redmine:#175412]  
	DB: DBTXN.bodb02
		   
*/
USE bodb02
GO

ALTER TABLE dbo.TicketVoiding_AutoVoidRequest_Queue ADD BroadcastSessionId VARCHAR(50)
GO
