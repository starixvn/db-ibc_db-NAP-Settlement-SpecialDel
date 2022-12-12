
    /*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20221129@July
	Task: Drop column un-used  [Redmine:#180625]  
	DB: DBARC.bodb_Archive
		   
*/
USE bodb_Archive
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single_bk ADD IsProcessed TINYINT;

ALTER TABLE TicketVoiding_RequestDetailTicket_SubParlay_bk ADD IsProcessed TINYINT;
