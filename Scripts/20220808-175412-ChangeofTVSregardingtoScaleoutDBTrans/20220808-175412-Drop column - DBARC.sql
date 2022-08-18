/*<info serverAlias="DBARC-bodb_Archive" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@July
	Task: Add new column SiteDBGroupID  [Redmine:#175412]  
	DB: DBARC.bodb_Archive
		   
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single_bk ADD SiteDBGroupID SMALLINT
GO
ALTER TABLE TicketVoiding_RequestDetailTicket_SubParlay_bk ADD SiteDBGroupID SMALLINT
GO