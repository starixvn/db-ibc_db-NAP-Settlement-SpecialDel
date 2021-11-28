/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20211129@Kathy
	Task: Add 2 new column [Redmine:#164819]  
	DB: DBARC.bodb_Archive
		   
*/
USE bodb_archive
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single_bk ADD Bettype SMALLINT
GO
ALTER TABLE TicketVoiding_RequestDetailTicket_Single_bk ADD BetId BIGINT
GO
