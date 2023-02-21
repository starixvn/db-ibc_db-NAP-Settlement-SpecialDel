/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230221@July
	Task: Add column IsCancelCO into TicketVoiding_RequestDetailTicket_Single_bk   [Redmine:#176998]  
	DB: DBARC.bodb_Archive
		   
*/
USE bodb_Archive
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single_bk ADD IsCancelCO BIT;
