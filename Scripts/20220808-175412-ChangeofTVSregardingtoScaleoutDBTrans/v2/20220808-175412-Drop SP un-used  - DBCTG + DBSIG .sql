/*<info serverAlias="DBCTG-bodb02, DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20220808@July
	Task: Drop SP un-used  [Redmine:#175412]  
	DB: DBCTG-bodb02, DBSIG-bodb02
		   
*/
USE bodb02

DROP PROCEDURE dbo.NAP_Admin_CheckingCashOutProcess
GO
DROP PROCEDURE TicketVoiding_RequestDetail_Insert
GO
DROP PROCEDURE TicketVoiding_RequestDetail_Update
GO
DROP PROCEDURE TicketVoiding_RequestDetailTicket_Single_Insert
GO
DROP PROCEDURE TicketVoiding_RequestDetailTicket_SubParlay_Insert
GO
DROP PROCEDURE TicketVoiding_VoidTime_Select
GO
