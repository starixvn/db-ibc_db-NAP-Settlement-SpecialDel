/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Add column IsProcessed into TicketVoiding_RequestDetailTicket_Single/SubParlay  [Redmine:#180625]  
	DB: DBCTG-bodb02
	
	Note: Replication DBTrans_API_Data
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single ADD IsProcessed TINYINT;

ALTER TABLE TicketVoiding_RequestDetailTicket_SubParlay ADD IsProcessed TINYINT;