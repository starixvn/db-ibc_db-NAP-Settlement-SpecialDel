/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230221@July
	Task: Add column IsCancelCO into TicketVoiding_RequestDetailTicket_Single [Redmine:#176998]  
	DB: DBCTG-bodb02
	
	Note: Replication DBTrans_API_Data
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single ADD IsCancelCO BIT;
