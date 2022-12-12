/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Add column MessageHash into TicketVoiding_VoidingHistory [Redmine:#180625]  
	DB: DBCTG-bodb02
	
	Note: Replication DBTrans_API_Data
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_VoidingHistory ADD MessageHash VARCHAR(1000);