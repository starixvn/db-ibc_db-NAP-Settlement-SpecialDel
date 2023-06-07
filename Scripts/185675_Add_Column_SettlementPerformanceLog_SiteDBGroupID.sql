/*<info serverAlias="DBLOG-bodb_CustomerLog_Archive" executers="" viewers="" isFunction="0"></info>*/

/*
	Created: 20230605@Louisa
	Task : Add column SiteDBGroupId [Redmine:#185675]
	DB: DBLOG/bodb_CustomerLog_Archive 
	
	Revision:
		- 20230605@Louisa: Add column SiteDBGroupId [Redmine:#185675]
	
*/
USE bodb_CustomerLog_Archive
GO

ALTER TABLE SettlementPerformanceLog ADD SiteDBGroupId SMALLINT
GO
