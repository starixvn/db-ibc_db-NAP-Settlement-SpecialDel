/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created: July
    Date: 20200909
    Task : [TVS] - Enhance for Danger Accept - Phase 2 [Redmine: #140785]
    DB: bodb02 - DBTRANS & Replicated Server for DBTrans_API_Data
*/

USE bodb02
GO

ALTER TABLE dbo.TicketVoiding_RequestDetail 
ADD 
	 IsCheckedHomeTeam BIT NULL
	,IsCheckedAwayTeam BIT NULL
GO

