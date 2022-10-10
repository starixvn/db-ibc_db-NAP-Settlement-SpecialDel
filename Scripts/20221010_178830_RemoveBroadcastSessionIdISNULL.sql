/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221010@July
	Task: Delete auto void queue is null  [Redmine:#178830]  
	DB: DBCTG.bodb02, DBSIG.bodb02
		   
*/

DELETE FROM dbo.TicketVoiding_AutoVoidRequest_Queue WITH (ROWLOCK) WHERE BroadcastSessionId IS NULL