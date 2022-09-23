/*<info serverAlias="DBCTG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@July
	Task: Add new column & Create new table  [Redmine:#175412]  
	DB: DBCTG.bodb02
		   
*/
USE bodb02
GO

ALTER TABLE TicketVoiding_RequestDetailTicket_Single ADD SiteDBGroupID SMALLINT
GO
ALTER TABLE TicketVoiding_RequestDetailTicket_SubParlay ADD SiteDBGroupID SMALLINT
GO

