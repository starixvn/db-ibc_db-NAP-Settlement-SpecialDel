/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20211129@Kathy
	Task: Add 2 new column [Redmine:#164819]  
	DB: DBTXN.bodb02
		   
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single ADD Bettype SMALLINT
GO
ALTER TABLE TicketVoiding_RequestDetailTicket_Single ADD BetId BIGINT
GO
