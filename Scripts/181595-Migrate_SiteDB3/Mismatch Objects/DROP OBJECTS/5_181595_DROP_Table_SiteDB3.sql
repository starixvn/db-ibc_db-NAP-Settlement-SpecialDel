/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230626@Louisa
    Task: Migrate data for SiteDB3 [Redmineid:#181595] 
    DB: DBSIG-bodb02

	Revisions:
		- 20230626@Louisa: DROP table, column, index, type table [Redmineid:#181595]					
	
*/

--- run on SiteDB3  only

USE bodb02
GO

	----DROP table type
	DROP TYPE IF EXISTS dbo.DEL_TVP_SiteDB_CalculationLog
	GO
	DROP TYPE IF EXISTS dbo.DEL_TVP_SiteDB_CalculationLog_3rd
	GO

	----DROP TABLE
	DROP TABLE DEL_bettrans_oldTransid 
	GO
	DROP TABLE DEL_bettransG_oldTransid 
 	GO
	DROP TABLE DEL_bettransLC_oldTransid 
 	GO
	DROP TABLE DEL_bettransRnG_oldTransid 
  	GO
	DROP TABLE DEL_SiteDB_SettlementLock 
 	GO
	DROP TABLE DEL_SiteDB_SettlementProcessing 
	GO
	DROP TABLE DEL_SiteDB_SettlementService_CalculationLog_3rd_History 
	GO
	DROP TABLE DEL_SiteDB_SettlementService_CalculationLog_History 
	GO
	DROP TABLE DEL_Transfer_oldTransid 
	GO
	DROP TABLE DEL_translog_oldTransid 
	GO






