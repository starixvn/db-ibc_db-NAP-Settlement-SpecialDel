/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
/*
	Created by: 20230706@July
	Task: [TVS] Drop SP/tables are not needed on sitedb3 and all sitedb  [Redmine:#190859]  
	DB: DBSIG-bodb02
	
*/
USE bodb02
GO
--Drop table only SITEDB3
IF OBJECT_ID('TicketVoiding_Letstalk','U') IS NOT NULL 
	DROP TABLE TicketVoiding_Letstalk
GO
